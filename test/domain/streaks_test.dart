import 'package:diet_app2/domain/body/body_weight.dart';
import 'package:diet_app2/domain/progress/streaks.dart';
import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/domain/training/training_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'current starts yesterday while today is incomplete; best crosses gaps',
    () {
      final result = computeStreak({
        '2026-11-01',
        '2026-11-02',
        '2026-11-04',
        '2026-11-05',
        '2026-11-06',
      }, DateTime(2026, 11, 7));
      expect(result.current, 3);
      expect(result.best, 3);
      expect(computeStreak({'2026-11-01'}, DateTime(2026, 11, 7)).current, 0);
    },
  );
  test('recap averages logged days, counts sessions and weight delta', () {
    final date = DateTime(2026, 11, 1);
    TrainingDay day(String key, bool done) => TrainingDay(
          dateKey: key,
          date: date,
          materializedFromPlanVersion: 1,
          items: [
            TrainingItem(
              localId: key,
              planItemId: 'p',
              exerciseId: 'plank',
              nameAr: 'بلانك',
              muscle: MuscleGroup.core,
              sets: 1,
              reps: 1,
              order: 0,
              done: done,
            ),
          ],
        );
    BodyWeightEntry weight(String key, double kg) => BodyWeightEntry(
          dateKey: key,
          date: DateTime.parse(key),
          kg: kg,
          createdAt: date,
          updatedAt: date,
        );
    final recap = WeeklyRecap.fromWindow(
      start: date,
      calories: [
        const DailyKcal('2026-11-01', 2000),
        const DailyKcal('2026-11-02', 1800),
      ],
      trainingDays: [day('2026-11-01', true), day('2026-11-02', false)],
      weights: [weight('2026-11-01', 80), weight('2026-11-06', 79)],
    );
    expect(recap.avgKcal, 1900);
    expect(recap.daysLogged, 2);
    expect(recap.sessionsDone, 1);
    expect(recap.sessionsPlanned, 2);
    expect(recap.weightDeltaKg, -1);
  });
  test('streak survives DST transitions and month ends', () {
    // Spans the EU spring change (Mar 29), the Egyptian spring change
    // (last Friday of April) and month boundaries. A local Duration(days: 1)
    // step skipped or split these days on DST-observing devices.
    final keys = <String>{};
    for (var d = DateTime(2026, 3, 25);
        !d.isAfter(DateTime(2026, 5, 2));
        d = DateTime(d.year, d.month, d.day + 1)) {
      keys.add(
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    final result = computeStreak(keys, DateTime(2026, 5, 2));
    expect(result.current, keys.length);
    expect(result.best, keys.length);
  });
}
