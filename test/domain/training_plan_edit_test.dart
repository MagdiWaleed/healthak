import 'package:flutter_test/flutter_test.dart';
import 'package:diet_app2/domain/training/training_plan_edit.dart';
import 'package:diet_app2/domain/training/workout_plan_item.dart';

void main() {
  test('reorder rewrites all day orders', () {
    final items = expandStarterTemplate(
        StarterTemplate.pushPullLegs, DateTime(2026), () => '${_next++}');
    final before = items.where((e) => e.daysOfWeek.contains(1)).toList();
    final after = reorderWorkoutDay(items, 1, 0, 3);
    final monday = after.where((e) => e.daysOfWeek.contains(1)).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    expect(monday.map((e) => e.id), [before[1].id, before[2].id, before[0].id]);
    expect(monday.map((e) => e.order), [0, 1, 2]);
  });
  test('templates expand library entries with defaults and designated days',
      () {
    final items = expandStarterTemplate(
        StarterTemplate.fullBodyThree, DateTime(2026), () => '${_next++}');
    expect(items, hasLength(9));
    expect(items.every((WorkoutPlanItem e) => e.sets == 3 && e.reps == 10),
        isTrue);
    expect(items.map((e) => e.daysOfWeek.single).toSet(), {1, 3, 5});
  });
}

int _next = 0;
