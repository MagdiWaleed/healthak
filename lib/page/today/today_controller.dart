import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/day_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/food/food_item.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/meal/meal_math.dart';
import '../../domain/nutrition/energy.dart';
import '../../domain/nutrition/macros.dart';
import '../../service/session_controller.dart';
import '../../ui/feedback/haptics.dart';
import '../../ui/theme/mood_palette.dart';

/// Backs the Today screen: materializes "today" from the schedule on open,
/// lets the user browse nearby days read-only, and owns the eat-toggle hot
/// path.
///
/// Materialization only ever runs for the real current date -- see
/// [selectDate]. Browsing to any other day just reads whatever document
/// exists there; nothing is ever invented for a day that hasn't been opened.
class TodayController extends GetxController {
  final String uid;
  final DayRepository _days;
  final SessionController _session;
  final Uuid _uuid;

  TodayController({
    required this.uid,
    DayRepository? days,
    SessionController? session,
    Uuid uuid = const Uuid(),
  })  : _days = days ?? DayRepository(uid: uid),
        _session = session ?? Get.find<SessionController>(),
        _uuid = uuid;

  /// Read by the home shell's FAB to decide whether tapping it should open
  /// the quick-add sheet (only meaningful while today, not some other browsed
  /// day, is selected).
  bool get isViewingToday => _isToday(selectedDate.value);

  final selectedDate = DateTime.now().obs;
  final day = Rxn<DayLog>();
  final loading = true.obs;
  final error = RxnString();
  final progress = 0.0.obs;
  final mood = DayMood.fresh.obs;

  /// Increasing tokens let short-lived visual effects replay without keeping
  /// animation state in the Firestore-backed [DayLog].
  final eatPulse = 0.obs;
  final goalCelebration = 0.obs;
  final goalCelebratedToday = false.obs;
  final _celebratedDateKeys = <String>{};

  StreamSubscription<DayLog?>? _watchSub;
  int _selectionEpoch = 0;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  void onInit() {
    super.onInit();
    selectDate(DateTime.now());
  }

  @override
  void onClose() {
    _watchSub?.cancel();
    super.onClose();
  }

  Future<void> selectDate(DateTime date) async {
    final epoch = ++_selectionEpoch;
    selectedDate.value = date;
    // Do not leave a previous day's content visible while the new local
    // Firestore snapshot is arriving.
    day.value = null;
    // Materialization can require a schedule read + transaction. The Today
    // screen must not wait for that network round trip before it starts its
    // own cache-backed day stream.
    loading.value = false;
    error.value = null;
    await _watchSub?.cancel();

    _watchSub = _days.watch(date).listen((value) {
      if (epoch != _selectionEpoch) return;
      day.value = value;
      _syncMood(value);
      goalCelebratedToday.value =
          value != null && _celebratedDateKeys.contains(value.dateKey);
    }, onError: (Object e) {
      if (epoch != _selectionEpoch) return;
      error.value = e.toString();
    });

    if (_isToday(date)) {
      final profile = _session.profile.value;
      if (profile != null) {
        unawaited(_materializeToday(
          date: date,
          targets: profile.targets,
          epoch: epoch,
        ));
      }
    }
  }

  Future<void> _materializeToday({
    required DateTime date,
    required NutritionTargets targets,
    required int epoch,
  }) async {
    try {
      await _days.ensureDay(date: date, targets: targets);
    } catch (e) {
      if (epoch == _selectionEpoch) error.value = e.toString();
    }
  }

  Future<void> retry() => selectDate(selectedDate.value);

  void _syncMood(DayLog? value, {double? previousProgress}) {
    final target = value?.targets.kcal ?? 0;
    final nextProgress =
        target <= 0 ? 0.0 : (value?.consumedKcal ?? 0) / target;
    progress.value = nextProgress;
    mood.value = MoodPalette.moodFor(nextProgress, previous: mood.value);

    // Crossing into the final 5% is a one-shot per day/session. Watching the
    // stream must never re-trigger it after rotation or a Firestore echo.
    if (value != null &&
        previousProgress != null &&
        previousProgress < .95 &&
        nextProgress >= .95 &&
        !_celebratedDateKeys.contains(value.dateKey)) {
      goalCelebratedToday.value = true;
      _celebratedDateKeys.add(value.dateKey);
      goalCelebration.value++;
      unawaited(HapticPhrase.play(AppHaptics.goal));
    }
  }

  Future<void> toggleEaten(String entryId) async {
    final current = day.value;
    if (current == null) return;
    // Optimistic: flip locally first so the ring re-tweens immediately, then
    // reconcile with what the transaction actually wrote.
    final entry =
        current.entries.where((e) => e.entryId == entryId).firstOrNull;
    if (entry == null) return;
    final before = progress.value;
    final updated = current.withEntry(entry.toggleEaten());
    day.value = updated;
    _syncMood(day.value, previousProgress: before);
    if (!entry.eaten) eatPulse.value++;
    try {
      // A transaction cannot complete while Firestore is offline, so the old
      // hot path visibly flipped and then rolled itself back. A normal set is
      // accepted by Firestore's local cache and queued for sync, preserving
      // the one-tap contract even through a short network outage.
      await _days.save(updated);
    } catch (e) {
      day.value = current; // roll back on failure
      _syncMood(current);
      error.value = e.toString();
    }
  }

  Future<void> deleteEntry(String entryId) async {
    final current = day.value;
    if (current == null) return;
    // Optimistic, for the same reason as toggleEaten -- but here it's load
    // bearing, not just responsive: the swipe-to-delete `Dismissible` plays
    // its own removal animation and then expects the item gone from the very
    // next build. Without removing it from `day.value` immediately, the
    // Firestore round trip finishes a beat later; if *any* other change
    // rebuilds the list in that window (an eat-toggle on another row, the
    // stream ticking), the just-dismissed item's key reappears in the tree
    // after `Dismissible` already reported it gone, which Flutter throws on:
    // "A dismissed Dismissible widget is still part of the tree."
    day.value = current.withoutEntry(entryId);
    _syncMood(day.value);
    try {
      await _days.removeEntry(current.dateKey, entryId);
    } catch (e) {
      day.value = current; // roll back on failure
      _syncMood(current);
      error.value = e.toString();
    }
  }

  /// Overwrites one entry's items -- the long-press gram editor's save path.
  /// Editing history directly like this is deliberate: a day is frozen from
  /// recipe edits, but the user must still be able to correct what they
  /// actually logged.
  Future<void> updateEntryItems(String entryId, List<FrozenItem> items) async {
    final current = day.value;
    if (current == null) return;
    final entry =
        current.entries.where((e) => e.entryId == entryId).firstOrNull;
    if (entry == null) return;
    await _days.upsertEntry(current.dateKey, entry.copyWith(items: items));
  }

  /// "أضف مكوّناً سريعاً": one food, logged with no meal around it.
  Future<void> quickAddFood(FoodItem food,
      {double grams = 100, MealSlot? slot}) async {
    final current = day.value;
    if (current == null || !_isToday(selectedDate.value)) return;
    await _days.upsertEntry(
      current.dateKey,
      DayEntry(
        entryId: _uuid.v4(),
        origin: DayEntryOrigin.quickAdd,
        name: food.name,
        slot: slot ?? _inferSlot(),
        order: current.entries.length,
        items: [
          FrozenItem(
            foodId: food.id,
            name: food.name,
            per100: food.per100,
            grams: grams,
          ),
        ],
      ),
    );
  }

  /// "أضف وجبة من مكتبتي": logs a full library meal as a one-shot.
  Future<void> addLibraryMeal(
    MealDefinition meal,
    MealResolver resolver, {
    MealSlot? slot,
  }) async {
    final current = day.value;
    if (current == null || !_isToday(selectedDate.value)) return;
    final flat = flattenMeal(meal, resolver);
    await _days.upsertEntry(
      current.dateKey,
      DayEntry(
        entryId: _uuid.v4(),
        origin: DayEntryOrigin.oneShot,
        sourceMealId: meal.id,
        name: meal.name,
        slot: slot ?? _inferSlot(),
        order: current.entries.length,
        items: [for (final f in flat) FrozenItem.fromFlat(f)],
      ),
    );
  }

  MealSlot _inferSlot() {
    final hour = DateTime.now().hour;
    if (hour < 11) return MealSlot.breakfast;
    if (hour < 16) return MealSlot.lunch;
    if (hour < 21) return MealSlot.dinner;
    return MealSlot.snack;
  }

  Macros get consumedMacros => day.value?.consumedTotals ?? Macros.zero;
  Macros get targetMacros => day.value?.targets.macros ?? Macros.zero;

  /// Everything planned for the day, eaten or not -- what "أضف/احذف؟" against
  /// the goal should actually be judged against, not just what's ticked off
  /// so far. Feeds the calorie ring's faded preview band.
  double get plannedKcal => day.value?.plannedKcal ?? 0;
  Macros get plannedMacros => day.value?.plannedTotals ?? Macros.zero;

  /// Basal metabolic rate, recomputed from the live profile rather than
  /// cached -- so it reflects the current weight/height/age even before a
  /// profile edit's new target has propagated to today's frozen `DayLog`.
  double? get bmr {
    final profile = _session.profile.value;
    if (profile == null) return null;
    return bmrMifflinStJeor(
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
      ageYears: profile.ageAt(DateTime.now()),
      sex: profile.sex,
    );
  }

  double get targetKcal => day.value?.targets.kcal ?? 0;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
