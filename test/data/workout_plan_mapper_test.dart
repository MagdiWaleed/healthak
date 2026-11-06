import 'package:diet_app2/data/mappers/workout_plan_mapper.dart';
import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/domain/training/workout_plan_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan round-trip keeps weekday order and fields', () {
    final now = DateTime(2026, 11, 6);
    final item = WorkoutPlanItem(
      id: 'p',
      exerciseId: 'bench_press',
      nameAr: 'ضغط بالبار على البنش',
      muscle: MuscleGroup.chest,
      sets: 4,
      reps: 8,
      daysOfWeek: {5, 1},
      order: 2,
      active: false,
      createdAt: now,
      updatedAt: now,
    );
    final json = WorkoutPlanMapper.toJson(item);
    expect(json['daysOfWeek'], [1, 5]);
    final restored = WorkoutPlanMapper.fromJson(json, id: item.id);
    expect(restored.daysOfWeek, {1, 5});
    expect(restored.muscle, item.muscle);
    expect(restored.active, isFalse);
    expect(restored.createdAt, now);
  });
}
