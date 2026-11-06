import 'package:diet_app2/domain/training/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('library ids are unique and major groups covered', () {
    expect(kExerciseLibrary.length, greaterThanOrEqualTo(50));
    expect(
      kExerciseLibrary.map((e) => e.id).toSet().length,
      kExerciseLibrary.length,
    );
    for (final group in MuscleGroup.values.where(
      (g) => g != MuscleGroup.fullBody,
    )) {
      expect(kExerciseLibrary.any((e) => e.muscle == group), isTrue);
      expect(muscleLabelAr(group), isNotEmpty);
    }
    expect(exerciseById('bench_press')?.nameAr, 'ضغط بالبار على البنش');
    expect(exerciseById('missing'), isNull);
  });
}
