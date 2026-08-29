import 'package:flutter/material.dart';

import '../../domain/nutrition/macros.dart';
import '../../l10n/app_strings.dart';
import '../glass/glass_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'macro_bar.dart';
import 'ticker_number.dart';

/// Readable macro progress for Today. The ring stays the visual headline;
/// this panel makes its three inner arcs useful when a user needs exact grams.
///
/// Each row shows the eaten grams as the headline number and, when today's
/// plan still has more of that macro coming, the planned figure beside it --
/// small, grey, with a faded dot that matches the faded segment on the bar.
class MacroNumbersPanel extends StatelessWidget {
  final Macros consumed;
  final Macros target;
  final Macros planned;
  final int animationTrigger;

  const MacroNumbersPanel({
    required this.consumed,
    required this.target,
    required this.planned,
    required this.animationTrigger,
    super.key,
  });

  bool _hasPlannedExtra(double eaten, double plan) => plan.round() > eaten.round();

  @override
  Widget build(BuildContext context) {
    final anyPlanned = _hasPlannedExtra(consumed.protein, planned.protein) ||
        _hasPlannedExtra(consumed.carbs, planned.carbs) ||
        _hasPlannedExtra(consumed.fat, planned.fat);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                AppStrings.macroConsumed,
                style: TextStyle(
                  fontSize: 11,
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (anyPlanned)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FadedDot(color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      AppStrings.macroPlanned,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppPalette.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _MacroProgressRow(
            label: AppStrings.protein,
            consumed: consumed.protein,
            target: target.protein,
            planned: planned.protein,
            color: AppPalette.emerald,
            animationTrigger: animationTrigger,
          ),
          const SizedBox(height: AppSpacing.sm),
          _MacroProgressRow(
            label: AppStrings.carbs,
            consumed: consumed.carbs,
            target: target.carbs,
            planned: planned.carbs,
            color: AppPalette.amber,
            animationTrigger: animationTrigger,
            stagger: const Duration(milliseconds: 60),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MacroProgressRow(
            label: AppStrings.fat,
            consumed: consumed.fat,
            target: target.fat,
            planned: planned.fat,
            color: AppPalette.violet,
            animationTrigger: animationTrigger,
            stagger: const Duration(milliseconds: 120),
          ),
        ],
      ),
    );
  }
}

/// A hollow-looking dot at the same alpha the faded planned segment uses on
/// [MacroBar], so the grey planned number reads as "that faded part".
class _FadedDot extends StatelessWidget {
  final Color color;
  const _FadedDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .38),
          shape: BoxShape.circle,
        ),
      );
}

class _MacroProgressRow extends StatelessWidget {
  final String label;
  final double consumed;
  final double target;
  final double planned;
  final Color color;
  final int animationTrigger;
  final Duration stagger;

  const _MacroProgressRow({
    required this.label,
    required this.consumed,
    required this.target,
    required this.planned,
    required this.color,
    required this.animationTrigger,
    this.stagger = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final over = consumed > target && target > 0;
    final numberColor = over ? AppPalette.amber : AppPalette.text;
    final showPlanned = planned.round() > consumed.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(label)),
            TickerNumber(
              value: consumed.round(),
              format: (number) => '$number',
              style: TextStyle(
                color: numberColor,
                fontWeight: FontWeight.w800,
                fontFeatures: AppTypography.tabular,
              ),
            ),
            Text(
              ' / ${target.round()} ${AppStrings.grams}',
              style: const TextStyle(
                color: AppPalette.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                fontFeatures: AppTypography.tabular,
              ),
            ),
            if (showPlanned) ...[
              const SizedBox(width: 8),
              _FadedDot(color: color),
              const SizedBox(width: 3),
              Text(
                '${planned.round()}',
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        MacroBar(
          label: '',
          value: consumed,
          target: target,
          planned: planned,
          color: color,
          animationTrigger: animationTrigger,
          stagger: stagger,
          showHeader: false,
        ),
      ],
    );
  }
}
