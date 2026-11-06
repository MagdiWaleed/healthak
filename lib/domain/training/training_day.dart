import '../day/day_log.dart';
import 'exercise.dart';
import 'workout_plan_item.dart';

class TrainingItem {
  final String localId;
  final String? planItemId;
  final String exerciseId;
  final String nameAr;
  final MuscleGroup muscle;
  final int sets;
  final int reps;
  final int order;
  final bool done;
  final DateTime? doneAt;

  const TrainingItem({
    required this.localId,
    required this.planItemId,
    required this.exerciseId,
    required this.nameAr,
    required this.muscle,
    required this.sets,
    required this.reps,
    required this.order,
    this.done = false,
    this.doneAt,
  });

  TrainingItem toggle(DateTime now) => TrainingItem(
        localId: localId,
        planItemId: planItemId,
        exerciseId: exerciseId,
        nameAr: nameAr,
        muscle: muscle,
        sets: sets,
        reps: reps,
        order: order,
        done: !done,
        doneAt: done ? null : now,
      );
}

class TrainingDay {
  final String dateKey;
  final DateTime date;
  final List<TrainingItem> items;
  final int materializedFromPlanVersion;

  const TrainingDay({
    required this.dateKey,
    required this.date,
    required this.items,
    required this.materializedFromPlanVersion,
  });

  double get progress =>
      items.isEmpty ? 0 : items.where((e) => e.done).length / items.length;
  bool get isComplete => items.isNotEmpty && items.every((e) => e.done);
  bool get isRestDay => items.isEmpty;

  TrainingDay withToggled(String localId, DateTime now) {
    if (!items.any((e) => e.localId == localId)) {
      throw StateError('Training item $localId does not exist');
    }
    return TrainingDay(
      dateKey: dateKey,
      date: date,
      items: [
        for (final item in items)
          item.localId == localId ? item.toggle(now) : item,
      ],
      materializedFromPlanVersion: materializedFromPlanVersion,
    );
  }

  TrainingDay withOneOff(TrainingItem item) {
    if (item.planItemId != null) {
      throw ArgumentError('One-off item has a plan id');
    }
    if (items.any((e) => e.localId == item.localId)) {
      throw StateError('Duplicate training item ${item.localId}');
    }
    return TrainingDay(
      dateKey: dateKey,
      date: date,
      items: [...items, item],
      materializedFromPlanVersion: materializedFromPlanVersion,
    );
  }

  static TrainingDay materialize({
    required DateTime date,
    required List<WorkoutPlanItem> plan,
    TrainingDay? existing,
    required String Function() newId,
  }) {
    final selected = plan.where((e) => e.appliesTo(date)).toList()
      ..sort((a, b) {
        final order = a.order.compareTo(b.order);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
    final previous = {
      for (final e in existing?.items ?? <TrainingItem>[])
        if (e.planItemId != null) e.planItemId!: e,
    };
    final oneOffs = (existing?.items ?? <TrainingItem>[])
        .where((e) => e.planItemId == null)
        .toList();
    return TrainingDay(
      dateKey: DayLog.keyFor(date),
      date: DateTime(date.year, date.month, date.day),
      items: [
        for (final item in selected)
          TrainingItem(
            localId: previous[item.id]?.localId ?? newId(),
            planItemId: item.id,
            exerciseId: item.exerciseId,
            nameAr: item.nameAr,
            muscle: item.muscle,
            sets: item.sets,
            reps: item.reps,
            order: item.order,
            done: previous[item.id]?.done ?? false,
            doneAt: previous[item.id]?.doneAt,
          ),
        ...oneOffs,
      ],
      materializedFromPlanVersion: workoutPlanVersionOf(plan, date.weekday),
    );
  }
}
