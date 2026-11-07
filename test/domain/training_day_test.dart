import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/domain/training/training_day.dart';
import 'package:diet_app2/domain/training/workout_plan_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 11, 2); // Monday.
  WorkoutPlanItem item(
    String id,
    int order, {
    bool active = true,
    Set<int> days = const {1},
  }) =>
      WorkoutPlanItem(
        id: id,
        exerciseId: id,
        nameAr: id,
        muscle: MuscleGroup.chest,
        sets: 3,
        reps: 10,
        daysOfWeek: days,
        order: order,
        active: active,
        createdAt: date,
        updatedAt: date,
      );
  var id = 0;
  String newId() => '${++id}';

  test('materializes weekday order, retains checks and one-offs', () {
    final plan = [
      item('b', 2),
      item('a', 1),
      item('skip', 0, active: false),
      item('tuesday', 0, days: {2}),
    ];
    final first = TrainingDay.materialize(date: date, plan: plan, newId: newId);
    expect(first.items.map((e) => e.planItemId), ['a', 'b']);
    expect(first.progress, 0);
    final checked = first.withToggled(first.items.first.localId, date);
    expect(checked.progress, .5);
    const oneOff = TrainingItem(
      localId: 'one',
      planItemId: null,
      exerciseId: 'plank',
      nameAr: 'بلانك',
      muscle: MuscleGroup.core,
      sets: 1,
      reps: 1,
      order: 3,
    );
    final next = TrainingDay.materialize(
      date: date,
      plan: [item('a', 4)],
      existing: checked.withOneOff(oneOff),
      newId: newId,
    );
    expect(next.items.length, 2);
    expect(next.items.first.localId, first.items.first.localId);
    expect(next.items.first.doneAt, date);
    expect(next.items.last.localId, 'one');
    expect(next.withToggled('one', date).isComplete, isTrue);
    expect(
      TrainingDay.materialize(date: date, plan: [], newId: newId).isRestDay,
      isTrue,
    );
  });

  test('plan version is stable and changes on edit', () {
    final a = item('a', 0);
    final b = item('b', 1);
    expect(workoutPlanVersionOf([a, b], 1), workoutPlanVersionOf([b, a], 1));
    expect(
      workoutPlanVersionOf([a, b], 1),
      isNot(workoutPlanVersionOf([a.copyWith(reps: 12), b], 1)),
    );
    expect(workoutPlanVersionOf([a], 2), workoutPlanVersionOf([], 2));
  });

  test('completed removed plan items survive while incomplete ones are dropped',
      () {
    final first = TrainingDay.materialize(
        date: date, plan: [item('done', 0), item('pending', 1)], newId: newId);
    final completed = first.withToggled(first.items.first.localId, date);
    final next = TrainingDay.materialize(
        date: date, plan: [], existing: completed, newId: newId);
    expect(next.items.map((e) => e.planItemId), ['done']);
    expect(next.items.single.localId, first.items.first.localId);
    expect(next.items.single.done, isTrue);
    expect(next.items.single.doneAt, date);
  });
}
