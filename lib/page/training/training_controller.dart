import 'dart:async';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/training_day_repository.dart';
import '../../data/repositories/workout_plan_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/progress/streaks.dart';
import '../../domain/training/exercise.dart';
import '../../domain/training/training_day.dart';
import '../../domain/training/workout_plan_item.dart';
import '../../ui/feedback/haptics.dart';

class TrainingController extends GetxController {
  TrainingController(
      {required this.uid,
      TrainingDayRepository? days,
      WorkoutPlanRepository? plans,
      DateTime Function()? clock,
      Uuid uuid = const Uuid()})
      : _days = days ?? TrainingDayRepository(uid: uid),
        _plans = plans ?? WorkoutPlanRepository(uid: uid),
        _clock = clock ?? DateTime.now,
        _uuid = uuid;

  final String uid;
  final TrainingDayRepository _days;
  final WorkoutPlanRepository _plans;
  final DateTime Function() _clock;
  final Uuid _uuid;
  final selectedDate = DateTime.now().obs;
  final editingPast = false.obs;
  final day = Rxn<TrainingDay>();
  final plan = <WorkoutPlanItem>[].obs;
  final recentDays = <TrainingDay>[].obs;
  final loading = true.obs;
  final error = RxnString();
  final celebration = 0.obs;
  final _celebrated = <String>{};
  StreamSubscription<TrainingDay?>? _daySub;
  StreamSubscription<List<WorkoutPlanItem>>? _planSub;
  StreamSubscription<List<TrainingDay>>? _rangeSub;
  int _epoch = 0;
  bool _planHasEmitted = false;
  String? _togglePending;

  DateTime get today => _clock();
  bool get isToday =>
      DayLog.keyFor(selectedDate.value) == DayLog.keyFor(_clock());
  bool get canEdit => isToday || editingPast.value;
  int get doneCount => day.value?.items.where((e) => e.done).length ?? 0;
  int get totalSets => day.value?.items.fold<int>(0, (n, e) => n + e.sets) ?? 0;
  int get streak => computeStreak({
        for (final d in recentDays)
          if (d.isComplete) d.dateKey
      }, _clock())
          .current;

  @override
  void onInit() {
    super.onInit();
    _planSub = _plans.watchAll().listen((items) {
      _planHasEmitted = true;
      plan.assignAll(items);
      if (isToday) {
        unawaited(_days
            .ensureTrainingDay(selectedDate.value, items)
            .then((_) {}, onError: (Object e) => error.value = e.toString()));
      }
    }, onError: (Object e) => error.value = e.toString());
    final now = _clock();
    _rangeSub = _days
        .watchRange(DateTime(now.year, now.month, now.day - 29), now)
        .listen(recentDays.assignAll,
            onError: (Object e) => error.value = e.toString());
    unawaited(selectDate(now));
  }

  @override
  void onClose() {
    _daySub?.cancel();
    _planSub?.cancel();
    _rangeSub?.cancel();
    super.onClose();
  }

  Future<void> selectDate(DateTime date) async {
    final epoch = ++_epoch;
    selectedDate.value = DateTime(date.year, date.month, date.day);
    editingPast.value = false;
    day.value = null;
    loading.value = true;
    error.value = null;
    await _daySub?.cancel();
    if (epoch != _epoch) return;
    _daySub = _days.watch(selectedDate.value).listen((next) {
      if (epoch != _epoch) return;
      day.value = next;
      loading.value = false;
      if (_togglePending == next?.dateKey &&
          next!.isComplete &&
          _celebrated.add(next.dateKey)) {
        celebration.value++;
        unawaited(HapticPhrase.play(AppHaptics.goal));
      }
      _togglePending = null;
    }, onError: (Object e) {
      if (epoch == _epoch) {
        error.value = e.toString();
        loading.value = false;
      }
    });
    if (isToday && _planHasEmitted) {
      try {
        await _days.ensureTrainingDay(selectedDate.value, plan.toList());
      } catch (e) {
        if (epoch == _epoch) error.value = e.toString();
      }
    }
  }

  void toggleEditingPast() => editingPast.value = !editingPast.value;

  Future<void> toggle(String localId) async {
    if (!canEdit || day.value == null) return;
    _togglePending = day.value!.dateKey;
    try {
      await _days.toggle(selectedDate.value, localId);
    } catch (e) {
      _togglePending = null;
      error.value = e.toString();
    }
  }

  Future<void> addOneOff(Exercise exercise) async {
    if (!canEdit) return;
    try {
      await _days.addOneOff(
          selectedDate.value,
          TrainingItem(
            localId: _uuid.v4(),
            planItemId: null,
            exerciseId: exercise.id,
            nameAr: exercise.nameAr,
            muscle: exercise.muscle,
            sets: 3,
            reps: 10,
            order: day.value?.items.length ?? 0,
          ));
    } catch (e) {
      error.value = e.toString();
    }
  }
}
