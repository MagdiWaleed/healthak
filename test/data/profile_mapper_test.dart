import 'package:diet_app2/data/mappers/profile_mapper.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      onboardingComplete: true,
      createdAt: now,
      updatedAt: now,
    );

    final restored = ProfileMapper.fromJson(
      ProfileMapper.toCacheJson(original),
      uid: original.uid,
    );

    expect(restored.uid, original.uid);
    expect(restored.targets, original.targets);
    expect(restored.settings.graphicsQuality, GraphicsQuality.balanced);
    expect(restored.onboardingComplete, isTrue);
  });
}
