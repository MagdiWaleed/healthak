import 'package:flutter/material.dart';

import '../../domain/day/day_log.dart';
import '../../l10n/app_strings.dart';
import '../../ui/theme/app_colors.dart';

/// One glance for eaten energy and macros. Planned totals stay one tap away.
class TodaySummary extends StatelessWidget {
  final DayLog day;
  final bool showPlannedDetails;

  const TodaySummary(
      {required this.day, this.showPlannedDetails = true, super.key});

  @override
  Widget build(BuildContext context) {
    final target = day.targets.kcal;
    final eaten = day.consumedKcal;
    final difference = target - eaten;
    final progress = target <= 0 ? 0.0 : (eaten / target).clamp(0.0, 1.0);
    final consumed = day.consumedTotals;
    final targets = day.targets.macros;
    final remainingLabel =
        difference < 0 ? AppStrings.aboveTarget : AppStrings.remaining;
    final remainingColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(remainingLabel,
            style: const TextStyle(color: AppPalette.muted, fontSize: 12)),
        Text('${difference.abs().round()}',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: AppPalette.emerald)),
        const Text(AppStrings.kcal,
            style: TextStyle(color: AppPalette.muted, fontSize: 11)),
      ],
    );
    final consumedColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(AppStrings.todayEnergy,
            style: TextStyle(color: AppPalette.muted, fontSize: 12)),
        Text('${eaten.round()} / ${target.round()}',
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppPalette.text,
                fontWeight: FontWeight.w800,
                fontSize: 25)),
        const Text(AppStrings.kcal,
            style: TextStyle(color: AppPalette.muted, fontSize: 11)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: AppPalette.soft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(children: [
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    consumedColumn,
                    const SizedBox(height: 8),
                    remainingColumn
                  ],
                );
              }
              return Row(children: [
                consumedColumn,
                Expanded(child: remainingColumn),
              ]);
            }),
            const SizedBox(height: 13),
            Semantics(
              label: AppStrings.todayEnergy,
              value: AppStrings.energyProgress(eaten.round(), target.round()),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: AppPalette.outline,
                color: AppPalette.emerald,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 9),
        LayoutBuilder(builder: (context, constraints) {
          final cards = [
            _MacroProgress(
                label: AppStrings.protein,
                icon: Icons.egg_alt_rounded,
                value: consumed.protein,
                target: targets.protein,
                color: AppPalette.protein),
            _MacroProgress(
                label: AppStrings.carbs,
                icon: Icons.grain_rounded,
                value: consumed.carbs,
                target: targets.carbs,
                color: AppPalette.carbs),
            _MacroProgress(
                label: AppStrings.fat,
                icon: Icons.water_drop_rounded,
                value: consumed.fat,
                target: targets.fat,
                color: AppPalette.fat),
          ];
          if (constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(children: [
              for (final card in cards)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
            ]);
          }
          return Row(children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              Expanded(child: cards[i]),
            ],
          ]);
        }),
        if (showPlannedDetails) TodayPlannedDetails(day: day),
      ],
    );
  }
}

class TodayPlannedDetails extends StatelessWidget {
  final DayLog day;

  const TodayPlannedDetails({required this.day, super.key});

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('planned-${day.dateKey}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 2),
          childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          dense: true,
          minTileHeight: 34,
          title: const Text(AppStrings.plannedDetails,
              style: TextStyle(fontSize: 11, color: AppPalette.muted)),
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
      );
}

class _MacroProgress extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double target;
  final Color color;

  const _MacroProgress({
    required this.label,
    required this.icon,
    required this.value,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
              color.withValues(alpha: .08), AppPalette.surface),
          borderRadius: BorderRadius.circular(15),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 5),
          Text(AppStrings.macroAmount(value.round(), target.round()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppPalette.muted)),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: target <= 0 ? 0 : (value / target).clamp(0.0, 1.0),
            color: color,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: color.withValues(alpha: .12),
          ),
        ]),
      );
}
