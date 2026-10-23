import 'package:flutter/material.dart';

import '../../domain/day/day_log.dart';
import '../../l10n/app_strings.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/theme/app_colors.dart';

/// A compact daily overview. Planned amounts remain available on demand;
/// eating progress is always calculated from the frozen day record.
class TodaySummary extends StatelessWidget {
  final DayLog day;

  const TodaySummary({required this.day, super.key});

  @override
  Widget build(BuildContext context) {
    final target = day.targets.kcal;
    final difference = target - day.consumedKcal;
    final progress =
        target <= 0 ? 0.0 : (day.consumedKcal / target).clamp(0.0, 1.0);
    final consumed = day.consumedTotals;
    final targets = day.targets.macros;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(AppStrings.todayEnergy,
                            style: TextStyle(
                                color: AppPalette.muted, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text('${day.consumedKcal.round()}',
                            style: Theme.of(context).textTheme.displayMedium),
                        Text(AppStrings.outOfKcal(target.round()),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppPalette.soft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                            difference < 0
                                ? AppStrings.aboveTarget
                                : AppStrings.remaining,
                            style: const TextStyle(
                                fontSize: 11, color: AppPalette.emerald)),
                        Text('${difference.abs().round()}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.emerald)),
                        const Text(AppStrings.kcal,
                            style: TextStyle(
                                fontSize: 10, color: AppPalette.emerald)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                label: AppStrings.todayEnergy,
                value: AppStrings.energyProgress(
                    day.consumedKcal.round(), target.round()),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: AppPalette.soft,
                  color: AppPalette.emerald,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final items = [
            _MacroProgress(
                label: AppStrings.protein,
                value: consumed.protein,
                target: targets.protein,
                color: AppPalette.emerald),
            _MacroProgress(
                label: AppStrings.carbs,
                value: consumed.carbs,
                target: targets.carbs,
                color: AppPalette.amber),
            _MacroProgress(
                label: AppStrings.fat,
                value: consumed.fat,
                target: targets.fat,
                color: AppPalette.violet),
          ];
          // Large accessibility text gets a vertical layout rather than being
          // scaled down to fit a decorative three-column row.
          final stacked = constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
          if (stacked) {
            return Column(children: [
              for (final item in items)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: item),
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: items[i]),
            ],
          ]);
        }),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey('planned-${day.dateKey}'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            dense: true,
            title: const Text(AppStrings.plannedDetails,
                style: TextStyle(fontSize: 12, color: AppPalette.muted)),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                    AppStrings.plannedSummary(
                        day.plannedKcal.round(),
                        day.plannedTotals.protein.round(),
                        day.plannedTotals.carbs.round(),
                        day.plannedTotals.fat.round()),
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroProgress extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  const _MacroProgress(
      {required this.label,
      required this.value,
      required this.target,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: .055), Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(AppStrings.macroAmount(value.round(), target.round()),
              style: const TextStyle(fontSize: 11, color: AppPalette.muted)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: target <= 0 ? 0 : (value / target).clamp(0.0, 1.0),
            color: color,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: color.withValues(alpha: .1),
          ),
        ]),
      );
}
