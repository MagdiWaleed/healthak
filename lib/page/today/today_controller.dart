import 'dart:async';

import 'package:flutter/widgets.dart';
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
class TodayController extends GetxController with WidgetsBindingObserver {
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

  /// The real current date, as a **reactive** value rather than a bare
  /// `DateTime.now()` read at build time.
  ///
  /// This is load-bearing. The week strip decides which cells are tappable by
  /// comparing each date against "today"; when that comparison called
  /// `DateTime.now()` inline during `build`, a process that stayed alive
  /// across midnight kept whatever verdict it had reached before the
  /// rollover -- so the new day stayed greyed out as "tomorrow" and could
  /// never be selected, and the greeting kept naming the old day. Publishing
  /// the date instead means every dependent rebuilds the moment it rolls.
  final today = _dateOnly(DateTime.now()).obs;

  /// Unlocks a past day for correction.
  ///
  /// A past day is read-only by default so history is not edited by accident,
  /// but it must still be *possible* to fix -- forgetting to tick something
  /// off before midnight is normal, and a record that cannot be corrected is
  /// just a wrong record. Deliberately per-selection state, not persisted:
  /// [selectDate] clears it, so unlocking one day never leaves every other day
  /// unlocked behind it.
  final editingPast = false.obs;

  void toggleEditingPast() => editingPast.value = !editingPast.value;

  /// Whether the day currently in view accepts writes: today always, a past
  /// day only while deliberately unlocked. Gates adding as well as ticking --
  /// being able to untick a past day but not log a meal missing from it would
  /// be a strange half-correction.
  bool get canEditSelectedDay =>
      _isToday(selectedDate.value) || editingPast.value;

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

  /// `dateKey`s in the visible week that actually have a document.
  ///
  /// The week strip shows only these (plus today and whatever is selected):
  /// a chip for a day with nothing behind it just leads to a dead empty
  /// screen, so it should not be offered at all.
  final loggedDayKeys = <String>{}.obs;

  StreamSubscription<DayLog?>? _watchSub;
  StreamSubscription<List<DayLog>>? _weekSub;
  int _selectionEpoch = 0;

  /// True whenever the current selection is "today", not some other day the
  /// user browsed to. Used to tell a genuine day rollover (fix it silently)
  /// apart from the user having deliberately navigated away (leave them
  /// where they are).
  bool _followingToday = true;

  Timer? _rolloverTimer;

  /// True between asking for today's document to be materialized and that
  /// write landing. While it is set, a `null` from the watch stream means
  /// "the document is being created right now", not "this day has no
  /// record" -- so [loading] deliberately stays true and the empty state
  /// never flashes on the way in.
  bool _materializing = false;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isToday(DateTime date) => _dateOnly(date) == today.value;

  static DateTime _mondayOf(DateTime date) =>
      _dateOnly(date).subtract(Duration(days: date.weekday - 1));

  /// One bounded listener over the week the strip renders. Re-subscribed on
  /// rollover only when the week itself changed, so an ordinary midnight
  /// inside the same week costs nothing.
  void _watchWeek() {
    final monday = _mondayOf(today.value);
    if (_weekStart == monday) return;
    _weekStart = monday;
    _weekSub?.cancel();
    _weekSub = _days
        .watchRange(monday, monday.add(const Duration(days: 6)))
        .listen((days) {
      loggedDayKeys
        ..clear()
        ..addAll({for (final day in days) day.dateKey});
    }, onError: (Object _) {
      // A failed week query must not blank the strip -- worst case it keeps
      // showing the last known set, which is strictly better than a strip
      // with nothing on it but today.
    });
  }

  DateTime? _weekStart;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _scheduleRollover();
    _watchWeek();
    selectDate(DateTime.now());
  }

  @override
  void onClose() {
    _rolloverTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _watchSub?.cancel();
    _weekSub?.cancel();
    super.onClose();
  }

  /// Wakes exactly once at the next local midnight to republish [today].
  ///
  /// A repeating one-minute poll would do the same job while costing a wakeup
  /// every minute the app is open; a single timer to the boundary costs one.
  /// Rescheduled after each fire, and re-armed on resume, since a timer does
  /// not run while the process is frozen in the background.
  void _scheduleRollover() {
    _rolloverTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = _dateOnly(now).add(const Duration(days: 1));
    _rolloverTimer = Timer(nextMidnight.difference(now), () {
      _refreshToday();
      _scheduleRollover();
    });
  }

  /// Republishes [today] if the wall clock has moved to another date, and
  /// pulls the view along with it when the user was following today.
  void _refreshToday() {
    final current = _dateOnly(DateTime.now());
    if (current != today.value) today.value = current;
    _watchWeek();
    ensureCurrentDay();
  }

  /// A session left open (foregrounded or merely backgrounded) through
  /// midnight leaves [selectedDate] pinned to the day it was opened on --
  /// the ring, the entry list, and the FAB's "today only" guard all quietly
  /// go stale together, with the FAB refusing to add anything and no visible
  /// explanation why. Reselecting picks the real day back up. Only fires
  /// while the user was following today in the first place, so browsing
  /// history is never yanked out from under them.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // A backgrounded process does not run timers, so the rollover timer may
    // have been swallowed entirely while the app was away. Recompute rather
    // than trust it, and re-arm it for the next boundary.
    _refreshToday();
    _scheduleRollover();
  }

  void ensureCurrentDay() {
    if (_followingToday && !_isToday(selectedDate.value)) {
      unawaited(selectDate(DateTime.now()));
    }
  }

  Future<void> selectDate(DateTime date) async {
    final epoch = ++_selectionEpoch;
    _followingToday = _isToday(date);
    // Leaving a day re-locks it; an unlock is only ever for the day in view.
    editingPast.value = false;
    selectedDate.value = date;
    // Do not leave a previous day's content visible while the new local
    // Firestore snapshot is arriving.
    day.value = null;
    // Stay in the loading state until the first snapshot for the new day
    // actually arrives. Clearing it eagerly left a few frames of
    // `loading == false && day == null` -- the exact signature of "this day
    // has no record" -- so every day switch flashed the empty state before
    // the real content faded in.
    loading.value = true;
    error.value = null;
    _materializing = _isToday(date);
    await _watchSub?.cancel();

    _watchSub = _days.watch(date).listen((value) {
      if (epoch != _selectionEpoch) return;
      day.value = value;
      // A null while today's document is still being written is a
      // not-yet, not an answer. Any other null is the real, final state of
      // a past day that was never opened.
      if (value != null || !_materializing) loading.value = false;
      _syncMood(value);
      goalCelebratedToday.value =
          value != null && _celebratedDateKeys.contains(value.dateKey);
    }, onError: (Object e) {
      if (epoch != _selectionEpoch) return;
      loading.value = false;
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
    } finally {
      // Whether it succeeded or threw, the "document may still appear"
      // window is over: release the spinner so the watch's answer -- day or
      // empty state -- is what the screen shows.
      if (epoch == _selectionEpoch) {
        _materializing = false;
        loading.value = false;
      }
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
    if (current == null || !canEditSelectedDay) return;
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

  /// A one-off item with no catalog food behind it at all -- the user types
  /// the macros directly ("sushi with kabsa, random stuff, here's roughly
  /// what was in it"). Never writes to `foods` or any meal document; it
  /// exists only inside this day's frozen record, same as [quickAddFood].
  /// [macros] is treated as the whole logged amount (stored as `per100` at
  /// `grams: 100`), so there is nothing else for the user to weigh.
  Future<void> logCustomEntry({
    required String name,
    required Macros macros,
    MealSlot? slot,
  }) async {
    final current = day.value;
    if (current == null || !canEditSelectedDay) return;
    await _days.upsertEntry(
      current.dateKey,
      DayEntry(
        entryId: _uuid.v4(),
        origin: DayEntryOrigin.quickAdd,
        name: name,
        slot: slot ?? _inferSlot(),
        order: current.entries.length,
        items: [
          FrozenItem(
            foodId: 'manual:${_uuid.v4()}',
            name: name,
            per100: macros,
            grams: 100,
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
    if (current == null || !canEditSelectedDay) return;
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
