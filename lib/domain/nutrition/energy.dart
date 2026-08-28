import 'dart:math' as math;

import 'macros.dart';

/// Biological sex, required by the Mifflin-St Jeor equation.
///
/// This is a new field. The old `UserModel` collected height, weight, and age
/// and then ignored all three -- `calculateCalories()` was
/// `caloriesNeeds = dailyActive`, an identity function.
enum Sex {
  male,
  female,

  /// Uses the average of the male and female constants. Less accurate, but the
  /// alternative is refusing to compute anything.
  preferNotToSay,
}

extension SexLabel on Sex {
  String get labelAr => switch (this) {
        Sex.male => 'ذكر',
        Sex.female => 'أنثى',
        Sex.preferNotToSay => 'أفضل عدم القول',
      };
}

/// Activity multipliers applied to BMR to get TDEE.
///
/// The old sign-up UI told users to enter a number "between 1.2 and 1.9",
/// confirming a multiplier was always the intent -- but the model then used
/// that number directly as an absolute calorie count. A fixed enum removes both
/// the ambiguity and the `double.parse` crash surface on a free-text field.
enum ActivityLevel {
  sedentary(1.2, 'خامل'),
  light(1.375, 'نشاط خفيف'),
  moderate(1.55, 'نشاط متوسط'),
  high(1.725, 'نشاط عالٍ'),
  athlete(1.9, 'رياضي');

  const ActivityLevel(this.multiplier, this.labelAr);

  final double multiplier;
  final String labelAr;
}

enum Goal {
  cut('تنشيف'),
  maintain('الحفاظ على الوزن'),
  bulk('تضخيم');

  const Goal(this.labelAr);

  final String labelAr;
}

/// How a user's targets were arrived at.
enum TargetMode {
  /// Derived from BMR, activity, and goal.
  computed,

  /// The user typed their own kcal and macro split. Skips every calculation.
  manual,
}

/// Roughly 7700 kcal per kilogram of body mass.
const double kKcalPerKg = 7700;

/// Grams of protein per kg of bodyweight, and the range the waterfall may
/// squeeze it into before it starts cutting carbs to zero.
const double kDefaultProteinPerKg = 1.8;
const double kMinProteinPerKg = 1.6;
const double kMaxProteinPerKg = 2.2;

/// No single macro may exceed this share of total energy.
const double kMaxProteinShare = 0.40;
const double kMaxFatShare = 0.40;

/// Mifflin-St Jeor basal metabolic rate, in kcal/day.
///
///   male:   10*kg + 6.25*cm - 5*age + 5
///   female: 10*kg + 6.25*cm - 5*age - 161
///
/// `preferNotToSay` uses the midpoint of the two constants (-78).
double bmrMifflinStJeor({
  required double weightKg,
  required double heightCm,
  required int ageYears,
  required Sex sex,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
  final constant = switch (sex) {
    Sex.male => 5.0,
    Sex.female => -161.0,
    Sex.preferNotToSay => -78.0,
  };
  return math.max(0, base + constant);
}

/// Total daily energy expenditure.
double tdee({required double bmr, required ActivityLevel activity}) =>
    bmr * activity.multiplier;

/// The lowest daily intake we will ever recommend.
///
/// Never below BMR, and never below a hard floor -- eating under your basal
/// rate is not something the app should quietly suggest.
double energyFloor({required double bmr, required Sex sex}) {
  final hardFloor = sex == Sex.female ? 1200.0 : 1500.0;
  return math.max(bmr, hardFloor);
}

/// Daily kcal target.
///
/// `weeklyRateKg` is the intended rate of change per week; it becomes a daily
/// delta of `rate * 7700 / 7`. This replaces the old hardcoded `+/- 500`.
double dailyTarget({
  required double bmr,
  required ActivityLevel activity,
  required Goal goal,
  required double weeklyRateKg,
  required Sex sex,
}) {
  final maintenance = tdee(bmr: bmr, activity: activity);
  final delta = weeklyRateKg.abs() * kKcalPerKg / 7;

  final raw = switch (goal) {
    Goal.cut => maintenance - delta,
    Goal.bulk => maintenance + delta,
    Goal.maintain => maintenance,
  };

  final floor = energyFloor(bmr: bmr, sex: sex);
  final ceiling = math.max(floor, maintenance * 1.5);
  return raw.clamp(floor, ceiling);
}

/// A computed macro target plus whatever compromises were needed to reach it.
class MacroTarget {
  final Macros macros;

  /// True when the requested protein and fat did not leave room for carbs and
  /// the waterfall had to reduce them. Surface this in the UI rather than
  /// silently handing back numbers that do not match what the user asked for.
  final bool wasAdjusted;

  const MacroTarget({required this.macros, required this.wasAdjusted});

  double get kcal => macros.kcal;
}

/// Splits a kcal target into protein, fat, and carbs.
///
/// Protein and fat are anchored to bodyweight; carbs take the remainder. The
/// old `getCarp()` was a bare remainder with no floor, so a heavy user on a low
/// target got a negative carb target. This applies a deterministic waterfall
/// instead:
///
///   1. pull fat down toward 20% of energy
///   2. pull protein down toward the 1.6 g/kg minimum
///   3. floor carbs at zero
MacroTarget macroSplit({
  required double targetKcal,
  required double weightKg,
  double proteinPerKg = kDefaultProteinPerKg,
}) {
  if (targetKcal <= 0 || weightKg <= 0) {
    return const MacroTarget(macros: Macros.zero, wasAdjusted: false);
  }

  // What the user asked for.
  final desiredProtein =
      proteinPerKg.clamp(kMinProteinPerKg, kMaxProteinPerKg) * weightKg;
  final desiredFat = math.max(0.8 * weightKg, targetKcal * 0.25 / 9);

  // Floors that must survive even a very aggressive cut.
  final minProtein = kMinProteinPerKg * weightKg;
  final minFat = targetKcal * 0.20 / 9;

  // Share caps stop one macro dominating the budget -- but they yield to the
  // floors. On a low target for a heavy user the two genuinely conflict, and
  // preserving lean mass matters more than an arbitrary percentage limit.
  var protein = math.min(
    desiredProtein,
    math.max(minProtein, targetKcal * kMaxProteinShare / 4),
  );
  var fat = math.min(
    desiredFat,
    math.max(minFat, targetKcal * kMaxFatShare / 9),
  );

  var carbKcal = targetKcal - protein * 4 - fat * 9;

  if (carbKcal < 0) {
    // 1. Fat gives way first -- it has the most slack.
    fat = math.max(minFat, fat + carbKcal / 9);
    carbKcal = targetKcal - protein * 4 - fat * 9;
  }

  if (carbKcal < 0) {
    // 2. Then protein, down to the minimum that still protects lean mass.
    protein = math.max(minProtein, protein + carbKcal / 4);
    carbKcal = targetKcal - protein * 4 - fat * 9;
  }

  // 3. Whatever is left, carbs cannot go below zero.
  final carbs = math.max(0.0, carbKcal / 4);

  // Report any compromise, whether it came from a share cap or the waterfall.
  final adjusted = (protein - desiredProtein).abs() > 0.01 ||
      (fat - desiredFat).abs() > 0.01;

  return MacroTarget(
    macros: Macros(protein: protein, carbs: carbs, fat: fat),
    wasAdjusted: adjusted,
  );
}

/// A user's daily nutrition targets, frozen into each day's log so that
/// changing a goal never rewrites history.
class NutritionTargets {
  final TargetMode mode;
  final double kcal;
  final Macros macros;

  const NutritionTargets({
    required this.mode,
    required this.kcal,
    required this.macros,
  });

  static const NutritionTargets empty =
      NutritionTargets(mode: TargetMode.computed, kcal: 0, macros: Macros.zero);

  /// Derives targets from body stats. The whole chain in one call.
  factory NutritionTargets.compute({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required Sex sex,
    required ActivityLevel activity,
    required Goal goal,
    required double weeklyRateKg,
    double proteinPerKg = kDefaultProteinPerKg,
  }) {
    final bmr = bmrMifflinStJeor(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      sex: sex,
    );
    final target = dailyTarget(
      bmr: bmr,
      activity: activity,
      goal: goal,
      weeklyRateKg: weeklyRateKg,
      sex: sex,
    );
    final split = macroSplit(
      targetKcal: target,
      weightKg: weightKg,
      proteinPerKg: proteinPerKg,
    );

    return NutritionTargets(
      mode: TargetMode.computed,
      kcal: target,
      macros: split.macros,
    );
  }

  /// The user's own numbers, passed through untouched.
  factory NutritionTargets.manual({
    required double kcal,
    required Macros macros,
  }) =>
      NutritionTargets(mode: TargetMode.manual, kcal: kcal, macros: macros);

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'kcal': kcal,
        ...macros.toJson(),
      };

  factory NutritionTargets.fromJson(Map<String, dynamic> json) =>
      NutritionTargets(
        mode: TargetMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => TargetMode.computed,
        ),
        kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
        macros: Macros.fromJson(json),
      );

  @override
  bool operator ==(Object other) =>
      other is NutritionTargets &&
      other.mode == mode &&
      other.kcal == kcal &&
      other.macros == macros;

  @override
  int get hashCode => Object.hash(mode, kcal, macros);
}
