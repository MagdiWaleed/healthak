import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/day_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/food/food_item.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/meal/meal_math.dart';
import '../../domain/nutrition/macros.dart';
import '../../service/session_controller.dart';

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

  StreamSubscription<DayLog?>? _watchSub;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
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
    selectedDate.value = date;
    loading.value = true;
    error.value = null;
    await _watchSub?.cancel();

    if (_isToday(date)) {
      final profile = _session.profile.value;
      if (profile != null) {
        try {
          await _days.ensureDay(date: date, targets: profile.targets);
        } catch (e) {
          error.value = e.toString();
        }
      }
    }

    _watchSub = _days.watch(date).listen((value) {
      day.value = value;
      loading.value = false;
    }, onError: (Object e) {
      error.value = e.toString();
      loading.value = false;
    });
  }

  Future<void> retry() => selectDate(selectedDate.value);

  Future<void> toggleEaten(String entryId) async {
    final current = day.value;
    if (current == null) return;
    // Optimistic: flip locally first so the ring re-tweens immediately, then
    // reconcile with what the transaction actually wrote.
    final entry = current.entries.where((e) => e.entryId == entryId).firstOrNull;
    if (entry == null) return;
    day.value = current.withEntry(entry.toggleEaten());
    try {
      await _days.toggleEaten(current.dateKey, entryId);
    } catch (e) {
      day.value = current; // roll back on failure
      error.value = e.toString();
    }
  }

  Future<void> deleteEntry(String entryId) async {
    final current = day.value;
    if (current == null) return;
    await _days.removeEntry(current.dateKey, entryId);
  }

  /// Overwrites one entry's items -- the long-press gram editor's save path.
  /// Editing history directly like this is deliberate: a day is frozen from
  /// recipe edits, but the user must still be able to correct what they
  /// actually logged.
  Future<void> updateEntryItems(String entryId, List<FrozenItem> items) async {
    final current = day.value;
    if (current == null) return;
    final entry = current.entries.where((e) => e.entryId == entryId).firstOrNull;
    if (entry == null) return;
    await _days.upsertEntry(current.dateKey, entry.copyWith(items: items));
  }

  /// "أضف مكوّناً سريعاً": one food, logged with no meal around it.
  Future<void> quickAddFood(FoodItem food, {double grams = 100, MealSlot? slot}) async {
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
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
