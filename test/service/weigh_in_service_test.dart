import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/service/weigh_in_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 6);
  UserProfile profile(NutritionTargets targets) => UserProfile(
        uid: 'u',
        displayName: 'a',
        email: 'a@example.com',
        sex: Sex.male,
        birthYear: 1990,
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.cut,
        weeklyRateKg: .5,
        targets: targets,
        createdAt: now,
        updatedAt: now,
      );
  test('newest updates weight and computed targets; older does not', () {
    final p = profile(
      NutritionTargets.compute(
        weightKg: 80,
        heightCm: 180,
        ageYears: 36,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
        goal: Goal.cut,
        weeklyRateKg: .5,
      ),
    );
    final updated = profileAfterWeighIn(
      profile: p,
      kg: 78,
      dateKey: '2026-11-06',
      latestDateKey: '2026-11-06',
      now: now,
    )!;
    expect(updated.weightKg, 78);
    expect(updated.targets.kcal, isNot(p.targets.kcal));
    expect(
      profileAfterWeighIn(
        profile: p,
        kg: 78,
        dateKey: '2026-11-05',
        latestDateKey: '2026-11-06',
        now: now,
      ),
      isNull,
    );
  });
  test('manual targets survive a weigh-in', () {
    final p = profile(NutritionTargets.manual(kcal: 2000, macros: Macros.zero));
    final updated = profileAfterWeighIn(
      profile: p,
      kg: 77,
      dateKey: '2026-11-06',
      latestDateKey: null,
      now: now,
    )!;
    expect(updated.targets, p.targets);
  });
}
