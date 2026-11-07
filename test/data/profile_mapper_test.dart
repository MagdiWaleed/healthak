import 'package:diet_app2/data/mappers/profile_mapper.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deficit profile mapper round trips and absent field stays off', () {
    final now = DateTime(2026, 11, 7);
    final base = UserProfile(
      uid: 'u',
      displayName: '',
      email: '',
      sex: Sex.female,
      birthYear: 1990,
      heightCm: 165,
      weightKg: 65,
      activityLevel: ActivityLevel.light,
      goal: Goal.maintain,
      weeklyRateKg: 0,
      targets: NutritionTargets.empty,
      createdAt: now,
      updatedAt: now,
    );
    final off = ProfileMapper.fromJson(ProfileMapper.toJson(base), uid: 'u');
    expect(off.deficit, isNull);
    final on = base.copyWith(
        deficit: DeficitMode(level: DeficitLevel.strong, startedAt: now));
    final restored =
        ProfileMapper.fromJson(ProfileMapper.toCacheJson(on), uid: 'u');
    expect(restored.deficit?.level, DeficitLevel.strong);
    expect(restored.deficit?.startedAt, now);
    expect(restored.targets, NutritionTargets.empty);
  });
  test('same user snapshots with changed fields are distinct', () {
    final now = DateTime(2026, 8, 29);
    final original = UserProfile(
      uid: 'u1',
      displayName: 'Magdi',
      email: 'm@example.com',
      sex: Sex.male,
      birthYear: 1995,
      heightCm: 178,
      weightKg: 80,
      activityLevel: ActivityLevel.light,
      goal: Goal.cut,
      weeklyRateKg: .5,
      targets: NutritionTargets.compute(
        weightKg: 80,
        heightCm: 178,
        ageYears: 31,
        sex: Sex.male,
        activity: ActivityLevel.light,
        goal: Goal.cut,
        weeklyRateKg: .5,
      ),
      createdAt: now,
      updatedAt: now,
    );

    final changed = original.copyWith(
      activityLevel: ActivityLevel.moderate,
      updatedAt: now.add(const Duration(minutes: 1)),
    );

    // GetX uses equality to suppress duplicate Rx emissions. Equality by uid
    // made every Firestore update for an existing user disappear, leaving
    // Today with stale activity and target data after a profile save.
    expect(changed, isNot(equals(original)));
  });

  test('profile survives the cache mapper with settings and targets', () {
    final now = DateTime(2026, 8, 28);
    final original = UserProfile(
      uid: 'u1',
      displayName: 'Magdi',
      email: 'm@example.com',
      sex: Sex.male,
      birthYear: 1995,
      heightCm: 178,
      weightKg: 80,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.cut,
      weeklyRateKg: .5,
      targets: NutritionTargets.compute(
        weightKg: 80,
        heightCm: 178,
        ageYears: 31,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
        goal: Goal.cut,
        weeklyRateKg: .5,
      ),
      settings: const AppSettings(graphicsQuality: GraphicsQuality.balanced),
      goalWeightKg: 72,
      onboardingComplete: true,
      createdAt: now,
      updatedAt: now,
    );

    final restored = ProfileMapper.fromJson(
      ProfileMapper.toCacheJson(original),
      uid: original.uid,
    );

    expect(restored.uid, original.uid);
    expect(restored.goalWeightKg, 72);
    expect(restored.copyWith(clearGoalWeight: true).goalWeightKg, isNull);
    expect(restored.targets, original.targets);
    expect(restored.settings.graphicsQuality, GraphicsQuality.balanced);
    expect(restored.onboardingComplete, isTrue);
  });
}
