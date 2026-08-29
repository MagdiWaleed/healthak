import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/nutrition/energy.dart';
import '../../domain/profile/user_profile.dart';
import 'mapper_utils.dart';

class ProfileMapper {
  const ProfileMapper._();

  static UserProfile fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) =>
      fromJson(snapshot.data() ?? const {}, uid: snapshot.id);

  static Map<String, dynamic> toFirestore(UserProfile profile, SetOptions? _) =>
      toJson(profile);

  static UserProfile fromJson(Map<String, dynamic> json,
      {required String uid}) {
    final settings = stringMap(json['settings']);
    return UserProfile(
      uid: uid,
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      // Profiles written before `preferNotToSay` was dropped no longer
      // match any enum value and land on this fallback. Male is the
      // Mifflin-St Jeor default; the profile screen lets it be corrected.
      sex: enumValue(Sex.values, json['sex'], Sex.male),
      birthYear: intValue(json['birthYear'], DateTime.now().year - 25),
      heightCm: doubleValue(json['heightCm']),
      weightKg: doubleValue(json['weightKg']),
      activityLevel: enumValue(
          ActivityLevel.values, json['activityLevel'], ActivityLevel.sedentary),
      goal: enumValue(Goal.values, json['goal'], Goal.maintain),
      weeklyRateKg: doubleValue(json['weeklyRateKg']),
      targets: NutritionTargets.fromJson(stringMap(json['targets'])),
      settings: AppSettings(
        themeMode: enumValue(
            AppThemeMode.values, settings['themeMode'], AppThemeMode.dark),
        accent: enumValue(
            AccentChoice.values, settings['accent'], AccentChoice.emerald),
        graphicsQuality: enumValue(
          GraphicsQuality.values,
          settings['graphicsQuality'],
          GraphicsQuality.high,
        ),
        digits: enumValue(
            DigitStyle.values, settings['digits'], DigitStyle.western),
        units:
            enumValue(UnitSystem.values, settings['units'], UnitSystem.metric),
      ),
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      schemaVersion: intValue(json['schemaVersion'], 2),
      createdAt: dateValue(json['createdAt']),
      updatedAt: dateValue(json['updatedAt']),
    );
  }

  static Map<String, dynamic> toJson(UserProfile profile) => {
        'displayName': profile.displayName,
        'email': profile.email,
        'photoUrl': profile.photoUrl,
        'sex': profile.sex.name,
        'birthYear': profile.birthYear,
        'heightCm': profile.heightCm,
        'weightKg': profile.weightKg,
        'activityLevel': profile.activityLevel.name,
        'goal': profile.goal.name,
        'weeklyRateKg': profile.weeklyRateKg,
        'targets': profile.targets.toJson(),
        'settings': {
          'themeMode': profile.settings.themeMode.name,
          'accent': profile.settings.accent.name,
          'graphicsQuality': profile.settings.graphicsQuality.name,
          'digits': profile.settings.digits.name,
          'units': profile.settings.units.name,
        },
        'onboardingComplete': profile.onboardingComplete,
        'schemaVersion': profile.schemaVersion,
        'createdAt': Timestamp.fromDate(profile.createdAt),
        'updatedAt': Timestamp.fromDate(profile.updatedAt),
      };

  static Map<String, dynamic> toCacheJson(UserProfile profile) => {
        ...toJson(profile),
        'uid': profile.uid,
        'createdAt': profile.createdAt.toIso8601String(),
        'updatedAt': profile.updatedAt.toIso8601String(),
      };
}
