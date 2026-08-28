import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/day_repository.dart';
import '../../data/repositories/meal_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/schedule/schedule_item.dart';
import '../../service/session_controller.dart';

/// Backs the "وجباتي" tab: the meal library and the recurring schedule.
class MyMealsController extends GetxController {
  final String uid;
  final MealRepository _meals;
  final ScheduleRepository _schedule;
  final DayRepository _days;
  final SessionController _session;
  final Uuid _uuid;

  MyMealsController({
    required this.uid,
    MealRepository? meals,
    ScheduleRepository? schedule,
    DayRepository? days,
    SessionController? session,
    Uuid uuid = const Uuid(),
  })  : _meals = meals ?? MealRepository(uid: uid),
        _schedule = schedule ?? ScheduleRepository(uid: uid),
        _days = days ?? DayRepository(uid: uid),
        _session = session ?? Get.find<SessionController>(),
        _uuid = uuid;

  final library = <MealDefinition>[].obs;
  final schedule = <ScheduleItem>[].obs;
  final libraryLoading = true.obs;
  final scheduleLoading = true.obs;

  StreamSubscription<List<MealDefinition>>? _librarySub;
  StreamSubscription<List<ScheduleItem>>? _scheduleSub;

  @override
  void onInit() {
    super.onInit();
    _librarySub = _meals.watchAll().listen((value) {
      library.value = value;
      libraryLoading.value = false;
    });
    _scheduleSub = _schedule.watchAll().listen((value) {
      schedule.value = value;
      scheduleLoading.value = false;
    });
  }

  @override
  void onClose() {
    _librarySub?.cancel();
    _scheduleSub?.cancel();
    super.onClose();
  }

  /// Items for one slot, in display order.
  List<ScheduleItem> forSlot(MealSlot slot) =>
      (schedule.where((item) => item.slot == slot).toList()
        ..sort((a, b) => a.order.compareTo(b.order)));

  Future<void> deleteMeal(String id) => _meals.delete(id);

  Future<void> toggleActive(ScheduleItem item) =>
      _schedule.save(item.copyWith(active: !item.active));

  Future<void> toggleDay(ScheduleItem item, int day) {
    final days = Set.of(item.daysOfWeek);
    if (!days.remove(day)) days.add(day);
    return _schedule.save(item.copyWith(daysOfWeek: days));
  }

  Future<void> deleteScheduleItem(String id) => _schedule.delete(id);

  /// Swaps [item] with its neighbor in the same slot.
  ///
  /// A drag-reorder would need a nested `ReorderableListView` per slot inside
  /// one scroll view, which Flutter doesn't support directly. Up/down is a
  /// deliberately simpler stand-in for the same "reorderable" requirement --
  /// see the Step 2 deviations note.
  Future<void> move(ScheduleItem item, {required bool up}) async {
    final slotItems = forSlot(item.slot);
    final index = slotItems.indexWhere((i) => i.id == item.id);
    final swapWith = up ? index - 1 : index + 1;
    if (index == -1 || swapWith < 0 || swapWith >= slotItems.length) return;

    final other = slotItems[swapWith];
    await Future.wait([
      _schedule.save(item.copyWith(order: other.order)),
      _schedule.save(other.copyWith(order: item.order)),
    ]);
  }

  /// "أضف لليوم" shortcut on a schedule row: logs its frozen snapshot against
  /// today as a one-shot, without touching the recurring item itself.
  Future<bool> quickAddToday(ScheduleItem item) async {
    final profile = _session.profile.value;
    if (profile == null) return false;

    final now = DateTime.now();
    final day = await _days.ensureDay(date: now, targets: profile.targets);
    await _days.upsertEntry(
      day.dateKey,
      DayEntry(
        entryId: _uuid.v4(),
        origin: DayEntryOrigin.oneShot,
        sourceMealId: item.mealId,
        name: item.name,
        slot: item.slot,
        order: day.entries.length,
        items: item.snapshot,
      ),
    );
    return true;
  }
}
