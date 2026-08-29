import 'package:flutter/material.dart';

import '../../domain/nutrition/energy.dart';
import '../../domain/profile/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../glass/glass_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'ticker_number.dart';

/// Makes a computed target auditable: BMR, total burn, adjustment, target.
/// It deliberately reuses the existing nutrition functions; no equation lives
/// in the UI and manual targets never pretend to be derived recommendations.
class EnergyBreakdownCard extends StatelessWidget {
  final double weightKg;
  final double heightCm;
  final int ageYears;
  final Sex sex;
  final ActivityLevel activity;
  final Goal goal;
  final double weeklyRateKg;
  final NutritionTargets targets;

  EnergyBreakdownCard({
    required UserProfile profile,
    super.key,
  })  : weightKg = profile.weightKg,
        heightCm = profile.heightCm,
        ageYears = DateTime.now().year - profile.birthYear,
        sex = profile.sex,
        activity = profile.activityLevel,
        goal = profile.goal,
        weeklyRateKg = profile.weeklyRateKg,
        targets = profile.targets;

  const EnergyBreakdownCard.preview({
    required this.weightKg,
    required this.heightCm,
    required this.ageYears,
    required this.sex,
    required this.activity,
    required this.goal,
    required this.weeklyRateKg,
    required this.targets,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (targets.mode == TargetMode.manual) {
      return GlassCard(
        highlighted: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.energyManualTitle),
            const SizedBox(height: AppSpacing.xs),
            TickerNumber(
              value: targets.kcal.round(),
              format: (value) => '$value ${AppStrings.kcal}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppPalette.emerald,
                    fontFeatures: AppTypography.tabular,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(AppStrings.energyManualDescription,
                style: AppTypography.whisper),
          ],
        ),
      );
    }

    final bmr = bmrMifflinStJeor(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      sex: sex,
    );
    final totalBurn = tdee(bmr: bmr, activity: activity);
    final adjustment = targets.kcal - totalBurn;
    return GlassCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.energyBreakdownTitle),
          const SizedBox(height: AppSpacing.sm),
          _EnergyStep(
            label: AppStrings.energyBmr,
            detail: AppStrings.energyBmrDetail,
            value: bmr,
          ),
          _EnergyStep(
            label: AppStrings.energyActivity(activity.labelAr),
            detail: AppStrings.energyTdeeDetail,
            value: totalBurn,
          ),
          _EnergyStep(
            label: AppStrings.energyWeeklyGoal(goal.labelAr, weeklyRateKg),
            detail: AppStrings.energyAdjustmentDetail,
            value: adjustment,
            signed: true,
          ),
          _EnergyStep(
            label: AppStrings.energyTarget,
            detail: AppStrings.energyTargetDetail,
            value: targets.kcal,
            hero: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(AppStrings.energyExplanation, style: AppTypography.whisper),
        ],
      ),
    );
  }
}

class _EnergyStep extends StatelessWidget {
  final String label;
  final String detail;
  final double value;
  final bool signed;
  final bool hero;

  const _EnergyStep({
    required this.label,
    required this.detail,
    required this.value,
    this.signed = false,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 10, bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: 42,
              color: hero ? AppPalette.emerald : Colors.white.withValues(alpha: .18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: hero ? FontWeight.w800 : FontWeight.w600,
                          color: hero ? AppPalette.emerald : AppPalette.text)),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            TickerNumber(
              value: value.round(),
              format: (number) => '${signed && number > 0 ? '+' : ''}$number ${AppStrings.kcal}',
              style: (hero
                      ? AppTypography.heroNumber.copyWith(fontSize: 24)
                      : const TextStyle(fontWeight: FontWeight.w800))
                  .copyWith(color: hero ? AppPalette.emerald : AppPalette.text),
              textAlign: TextAlign.end,
            ),
          ],
        ),
      );
}
