import 'package:diet_app2/data/mappers/training_day_mapper.dart';
import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/domain/training/training_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('training day round-trip keeps completion and one-off provenance', () {
    final now = DateTime(2026, 11, 6);
    final day = TrainingDay(
      dateKey: '2026-11-06',
      date: now,
      materializedFromPlanVersion: 42,
      items: [
        TrainingItem(
          localId: 'a',
          planItemId: null,
          exerciseId: 'plank',
          nameAr: 'بلانك',
          muscle: MuscleGroup.core,
          sets: 2,
          reps: 30,
          order: 0,
          done: true,
          doneAt: now,
        ),
      ],
    );
    final restored = TrainingDayMapper.fromJson(
      TrainingDayMapper.toJson(day),
      dateKey: day.dateKey,
    );
    expect(restored.materializedFromPlanVersion, 42);
    expect(restored.items.single.planItemId, isNull);
    expect(restored.items.single.doneAt, now);
    expect(restored.items.single.muscle, MuscleGroup.core);
  });
}
