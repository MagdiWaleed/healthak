import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bmrMifflinStJeor', () {
    test('male, known value', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
      final bmr = bmrMifflinStJeor(
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        sex: Sex.male,
      );
      expect(bmr, closeTo(1780, 0.01));
    });

    test('female, known value', () {
      // 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
      final bmr = bmrMifflinStJeor(
        weightKg: 60,
        heightCm: 165,
        ageYears: 30,
        sex: Sex.female,
      );
      expect(bmr, closeTo(1320.25, 0.01));
    });

    test('preferNotToSay sits exactly between male and female', () {
      const args = (w: 70.0, h: 172.0, a: 28);
      final male = bmrMifflinStJeor(
          weightKg: args.w, heightCm: args.h, ageYears: args.a, sex: Sex.male);
      final female = bmrMifflinStJeor(
          weightKg: args.w, heightCm: args.h, ageYears: args.a, sex: Sex.female);
      final neutral = bmrMifflinStJeor(
        weightKg: args.w,
        heightCm: args.h,
        ageYears: args.a,
        sex: Sex.preferNotToSay,
      );
      expect(neutral, closeTo((male + female) / 2, 0.01));
    });

    test('uses height, weight and age -- all three change the result', () {
      double bmr({double w = 70, double h = 175, int a = 30}) =>
          bmrMifflinStJeor(
              weightKg: w, heightCm: h, ageYears: a, sex: Sex.male);

      // The old calculateCalories() ignored all three of these.
      expect(bmr(w: 90), greaterThan(bmr()));
      expect(bmr(h: 190), greaterThan(bmr()));
      expect(bmr(a: 60), lessThan(bmr()));
    });

    test('never returns negative', () {
      final bmr = bmrMifflinStJeor(
        weightKg: 1,
        heightCm: 1,
        ageYears: 120,
        sex: Sex.female,
      );
      expect(bmr, greaterThanOrEqualTo(0));
    });
  });

  group('ActivityLevel', () {
    test('multipliers span the 1.2 to 1.9 range the old UI advertised', () {
      expect(ActivityLevel.sedentary.multiplier, 1.2);
      expect(ActivityLevel.athlete.multiplier, 1.9);
    });

    test('multipliers increase monotonically', () {
      final values = ActivityLevel.values.map((a) => a.multiplier).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });

    test('tdee scales bmr by the multiplier', () {
      expect(
        tdee(bmr: 1800, activity: ActivityLevel.moderate),
        closeTo(1800 * 1.55, 0.01),
      );
    });
  });

  group('dailyTarget', () {
    const bmr = 1800.0;

    test('maintain returns tdee unchanged', () {
      final target = dailyTarget(
        bmr: bmr,
        activity: ActivityLevel.moderate,
        goal: Goal.maintain,
        weeklyRateKg: 0.5,
        sex: Sex.male,
      );
      expect(target, closeTo(bmr * 1.55, 0.01));
    });

    test('cut subtracts rate * 7700 / 7 per day', () {
      const maintenance = bmr * 1.55;
      final target = dailyTarget(
        bmr: bmr,
        activity: ActivityLevel.moderate,
        goal: Goal.cut,
        weeklyRateKg: 0.5,
        sex: Sex.male,
      );
      expect(target, closeTo(maintenance - 550, 0.01));
    });

    test('bulk adds the same delta', () {
      const maintenance = bmr * 1.55;
      final target = dailyTarget(
        bmr: bmr,
        activity: ActivityLevel.moderate,
        goal: Goal.bulk,
        weeklyRateKg: 0.5,
        sex: Sex.male,
      );
      expect(target, closeTo(maintenance + 550, 0.01));
    });

    test('a cut never drops below BMR', () {
      // An absurd rate that would otherwise produce a starvation target.
      final target = dailyTarget(
        bmr: bmr,
        activity: ActivityLevel.sedentary,
        goal: Goal.cut,
        weeklyRateKg: 2.0,
        sex: Sex.male,
      );
      expect(target, greaterThanOrEqualTo(bmr));
    });

    test('female hard floor applies when BMR is very low', () {
      const lowBmr = 1000.0;
      final target = dailyTarget(
        bmr: lowBmr,
        activity: ActivityLevel.sedentary,
        goal: Goal.cut,
        weeklyRateKg: 1.0,
        sex: Sex.female,
      );
      expect(target, greaterThanOrEqualTo(1200));
    });

    test('a bulk is capped at 1.5x maintenance', () {
      const maintenance = bmr * 1.2;
      final target = dailyTarget(
        bmr: bmr,
        activity: ActivityLevel.sedentary,
        goal: Goal.bulk,
        weeklyRateKg: 5.0,
        sex: Sex.male,
      );
      expect(target, lessThanOrEqualTo(maintenance * 1.5 + 0.01));
    });

    test('a negative weekly rate is treated as a magnitude', () {
      final a = dailyTarget(
        bmr: bmr,
        activity: ActivityLevel.moderate,
        goal: Goal.cut,
        weeklyRateKg: 0.5,
        sex: Sex.male,
      );
      final b = dailyTarget(
        bmr: bmr,
        activity: ActivityLevel.moderate,
        goal: Goal.cut,
        weeklyRateKg: -0.5,
        sex: Sex.male,
      );
      expect(a, closeTo(b, 0.01));
    });
  });

  group('macroSplit', () {
    test('protein defaults to 1.8 g per kg', () {
      final result = macroSplit(targetKcal: 2500, weightKg: 80);
      expect(result.macros.protein, closeTo(80 * 1.8, 0.01));
      expect(result.wasAdjusted, isFalse);
    });

    test('proteinPerKg is clamped into the 1.6 to 2.2 range', () {
      final low = macroSplit(targetKcal: 2500, weightKg: 80, proteinPerKg: 0.5);
      expect(low.macros.protein, closeTo(80 * kMinProteinPerKg, 0.01));

      final high = macroSplit(targetKcal: 2500, weightKg: 80, proteinPerKg: 9);
      expect(high.macros.protein, closeTo(80 * kMaxProteinPerKg, 0.01));
    });

    test('the three macros add back up to the target', () {
      final result = macroSplit(targetKcal: 2200, weightKg: 70);
      expect(result.macros.kcal, closeTo(2200, 1));
    });

    test('carbs never go negative -- the old getCarp() bug', () {
      // A heavy user on a very low target. The old code returned a bare
      // remainder here, which went negative and was never clamped.
      final result = macroSplit(targetKcal: 1200, weightKg: 120);
      expect(result.macros.carbs, greaterThanOrEqualTo(0));
      expect(result.wasAdjusted, isTrue);
    });

    test('the waterfall reduces fat before protein', () {
      final normal = macroSplit(targetKcal: 3000, weightKg: 80);
      final squeezed = macroSplit(targetKcal: 1600, weightKg: 100);

      // Fat has given way proportionally more than protein has.
      final fatRatio = squeezed.macros.fat / normal.macros.fat;
      final proteinRatio = squeezed.macros.protein / normal.macros.protein;
      expect(fatRatio, lessThan(proteinRatio));
    });

    test('protein is never squeezed below 1.6 g per kg', () {
      final result = macroSplit(targetKcal: 1000, weightKg: 110);
      expect(
        result.macros.protein,
        greaterThanOrEqualTo(110 * kMinProteinPerKg - 0.01),
      );
    });

    test('the 40 percent share cap holds unless a floor overrides it', () {
      // The cap and the 1.6 g/kg protein floor genuinely conflict on a low
      // target for a heavy user. The floor wins -- preserving lean mass beats
      // an arbitrary percentage limit -- so the cap is only asserted when the
      // floor leaves room for it.
      for (final kcal in [1200.0, 1800.0, 2500.0, 4000.0]) {
        for (final kg in [50.0, 80.0, 120.0]) {
          final r = macroSplit(targetKcal: kcal, weightKg: kg);
          final proteinFloorKcal = kMinProteinPerKg * kg * 4;

          if (proteinFloorKcal <= kcal * kMaxProteinShare) {
            expect(r.macros.protein * 4, lessThanOrEqualTo(kcal * 0.4 + 0.01),
                reason: 'protein share at $kcal kcal / $kg kg');
          }
          expect(r.macros.fat * 9, lessThanOrEqualTo(kcal * 0.4 + 0.01),
              reason: 'fat share at $kcal kcal / $kg kg');

          // Whatever the compromise, these two always hold.
          expect(r.macros.carbs, greaterThanOrEqualTo(0));
          expect(r.macros.kcal, lessThanOrEqualTo(kcal + 1),
              reason: 'never over budget at $kcal kcal / $kg kg');
        }
      }
    });

    test('a share-capped result reports wasAdjusted', () {
      // 1.8 g/kg of 120 kg is 216 g, far more than a 1200 kcal budget allows.
      final r = macroSplit(targetKcal: 1200, weightKg: 120);
      expect(r.wasAdjusted, isTrue);
      expect(r.macros.protein, lessThan(216));
    });

    test('degenerate inputs return zero rather than NaN', () {
      expect(macroSplit(targetKcal: 0, weightKg: 80).macros, Macros.zero);
      expect(macroSplit(targetKcal: 2000, weightKg: 0).macros, Macros.zero);
    });
  });

  group('NutritionTargets', () {
    test('compute chains bmr, tdee, target and split', () {
      final targets = NutritionTargets.compute(
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
        goal: Goal.cut,
        weeklyRateKg: 0.5,
      );

      expect(targets.mode, TargetMode.computed);
      expect(targets.kcal, closeTo(1780 * 1.55 - 550, 1));
      expect(targets.macros.kcal, closeTo(targets.kcal, 1));
    });

    test('manual mode passes the numbers straight through', () {
      const macros = Macros(protein: 150, carbs: 200, fat: 60);
      final targets = NutritionTargets.manual(kcal: 1940, macros: macros);

      expect(targets.mode, TargetMode.manual);
      expect(targets.kcal, 1940);
      expect(targets.macros, macros);
    });

    test('survives a json round trip', () {
      final original = NutritionTargets.compute(
        weightKg: 72,
        heightCm: 168,
        ageYears: 41,
        sex: Sex.female,
        activity: ActivityLevel.light,
        goal: Goal.bulk,
        weeklyRateKg: 0.25,
      );
      final restored = NutritionTargets.fromJson(original.toJson());
      expect(restored, original);
    });
  });
}
