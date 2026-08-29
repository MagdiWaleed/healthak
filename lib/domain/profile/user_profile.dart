import '../nutrition/energy.dart';

enum AppThemeMode { dark, light, system }

enum AccentChoice { emerald, teal, violet, amber }

enum GraphicsQuality { high, balanced, low }

enum DigitStyle { western, arabicIndic }

enum UnitSystem { metric, imperial }

class AppSettings {
  final AppThemeMode themeMode;
  final AccentChoice accent;
  final GraphicsQuality graphicsQuality;
  final DigitStyle digits;
  final UnitSystem units;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.accent = AccentChoice.emerald,
    this.graphicsQuality = GraphicsQuality.high,
    this.digits = DigitStyle.western,
    this.units = UnitSystem.metric,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AccentChoice? accent,
    GraphicsQuality? graphicsQuality,
    DigitStyle? digits,
    UnitSystem? units,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
        graphicsQuality: graphicsQuality ?? this.graphicsQuality,
        digits: digits ?? this.digits,
        units: units ?? this.units,
      );
}

/// The authenticated user's profile at `users/{uid}`.
class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final Sex sex;
  final int birthYear;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;
  final Goal goal;
  final double weeklyRateKg;
  final NutritionTargets targets;
  final AppSettings settings;
  final bool onboardingComplete;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
    required this.weeklyRateKg,
    required this.targets,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
    this.settings = const AppSettings(),
    this.onboardingComplete = false,
    this.schemaVersion = 2,
  });

  int ageAt(DateTime date) => (date.year - birthYear).clamp(0, 130);

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    Sex? sex,
    int? birthYear,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    Goal? goal,
    double? weeklyRateKg,
    NutritionTargets? targets,
    AppSettings? settings,
    bool? onboardingComplete,
    DateTime? updatedAt,
  }) =>
      UserProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        sex: sex ?? this.sex,
        birthYear: birthYear ?? this.birthYear,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        goal: goal ?? this.goal,
        weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
        targets: targets ?? this.targets,
        settings: settings ?? this.settings,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}
