import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/progress/streaks.dart';
import 'package:flutter_test/flutter_test.dart';

/// A day with [target] kcal and one eaten entry of [eatenKcal] (all carbs,
/// so kcal = grams of carbs * 4 per 100 g portion).
DayLog _day({required double target, required double eatenKcal}) => DayLog(
      dateKey: '2026-11-07',
      date: DateTime(2026, 11, 7),
      targets: NutritionTargets.manual(kcal: target, macros: Macros.zero),
      entries: [
        if (eatenKcal > 0)
          DayEntry(
            entryId: 'e',
            origin: DayEntryOrigin.oneShot,
            name: 'e',
            slot: MealSlot.lunch,
            order: 0,
            eaten: true,
            items: [
              FrozenItem(
                foodId: 'f',
                name: 'f',
                per100: Macros(protein: 0, carbs: eatenKcal / 4, fat: 0),
                grams: 100,
              ),
            ],
          ),
      ],
    );

void main() {
  test('within ±10% of target is a hit', () {
    expect(isCalorieHit(_day(target: 2000, eatenKcal: 2000)), isTrue);
    expect(isCalorieHit(_day(target: 2000, eatenKcal: 1800)), isTrue);
    expect(isCalorieHit(_day(target: 2000, eatenKcal: 2200)), isTrue);
  });

  test('over-eating or under-eating beyond 10% is not a hit', () {
    expect(isCalorieHit(_day(target: 2000, eatenKcal: 2300)), isFalse);
    expect(isCalorieHit(_day(target: 2000, eatenKcal: 1500)), isFalse);
  });

  test('nothing eaten or no target is never a hit', () {
    expect(isCalorieHit(_day(target: 2000, eatenKcal: 0)), isFalse);
    expect(isCalorieHit(_day(target: 0, eatenKcal: 500)), isFalse);
  });
}
