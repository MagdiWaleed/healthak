import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/domain/progress/streaks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 7);
  const usual = NutritionTargets(
      mode: TargetMode.manual,
      kcal: 2100,
      macros: Macros(protein: 140, carbs: 200, fat: 70));
  UserProfile profile() => UserProfile(
      uid: 'u',
      displayName: '',
      email: '',
      sex: Sex.male,
      birthYear: 1996,
      heightCm: 180,
      weightKg: 80,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.maintain,
      weeklyRateKg: 0,
      targets: usual,
      createdAt: now,
      updatedAt: now);

  test('all deficit levels use TDEE and protein-only macros', () {
    for (final level in DeficitLevel.values) {
      final target = NutritionTargets.deficit(
          weightKg: 80,
          heightCm: 180,
          ageYears: 30,
          sex: Sex.male,
          activity: ActivityLevel.moderate,
          level: level);
      expect(target.kcal, closeTo(1780 * 1.55 * (1 - level.fraction), .001));
      expect(target.macros.protein, 144);
      expect(target.macros.carbs, 0);
      expect(target.macros.fat, 0);
      expect(NutritionTargets.fromJson(target.toJson()), target);
    }
    expect(NutritionTargets.fromJson({'kcal': 2100}).mode, TargetMode.computed);
  });

  test('energy floor clamps a sedentary strong deficit', () {
    final target = NutritionTargets.deficit(
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        sex: Sex.male,
        activity: ActivityLevel.sedentary,
        level: DeficitLevel.strong);
    expect(target.kcal, 1780);
  });

  test('turning mode off restores exact normal targets', () {
    final on = profile().copyWith(
        deficit: DeficitMode(level: DeficitLevel.medium, startedAt: now));
    expect(on.targets, same(usual));
    expect(on.effectiveTargets.mode, TargetMode.deficit);
    final off = on.copyWith(clearDeficit: true);
    expect(off.deficit, isNull);
    expect(off.effectiveTargets, same(usual));
  });

  test('deficit calorie hit accepts any positive intake within budget', () {
    const deficit = NutritionTargets(
        mode: TargetMode.deficit, kcal: 2000, macros: Macros.zero);
    DayLog day(NutritionTargets target, double kcal) =>
        DayLog.empty(now, target).withEntry(DayEntry(
          entryId: 'e',
          origin: DayEntryOrigin.quickAdd,
          name: 'food',
          slot: MealSlot.snack,
          order: 0,
          eaten: true,
          items: [
            FrozenItem(
                foodId: 'f',
                name: 'food',
                per100: Macros(protein: kcal / 4, carbs: 0, fat: 0),
                grams: 100)
          ],
        ));
    expect(isCalorieHit(day(deficit, 100)), isTrue);
    expect(isCalorieHit(day(deficit, 2000)), isTrue);
    expect(isCalorieHit(day(deficit, 2001)), isFalse);
    expect(isCalorieHit(day(deficit, 0)), isFalse);
    expect(isCalorieHit(day(usual, 100)), isFalse);
    expect(isCalorieHit(day(usual, 2100)), isTrue);
  });
}
