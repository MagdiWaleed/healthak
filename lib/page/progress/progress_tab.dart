import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_routes.dart';
import '../../domain/body/body_weight.dart';
import '../../domain/day/day_log.dart';
import '../../domain/progress/streaks.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/components/shimmer_box.dart';
import '../../ui/components/stat_tile.dart';
import '../../ui/components/weight_chart.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/motion.dart';
import '../../ui/theme/app_colors.dart';
import '../me/me_tab.dart';
import 'progress_controller.dart';
import 'weight_entry_sheet.dart';

class ProgressTab extends GetView<ProgressController> {
  const ProgressTab({super.key});

  Future<void> _delete(BuildContext context, BodyWeightEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.progressDeleteTitle),
        content: const Text(AppStrings.progressDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.assistantCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deleteWeight(entry);
    } catch (_) {
      if (context.mounted) {
        GlassSnackBar.show(context, AppStrings.saveFailed,
            tone: GlassSnackTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        if (controller.loading.value) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              ShimmerBox(height: 170),
              SizedBox(height: 12),
              ShimmerBox(height: 72),
              SizedBox(height: 12),
              ShimmerBox(height: 72),
            ]),
          );
        }
        if (controller.error.value != null) {
          return const Center(child: Text(AppStrings.progressLoadFailed));
        }
        final entries = controller.visibleWeights;
        final trend = controller.trend;
        final recap = controller.recap;
        final goal = controller.goalKg;
        final rows = <Widget>[
          Text(AppStrings.progress,
              style: Theme.of(context).textTheme.headlineMedium),
          const SectionHeader(title: AppStrings.progressWeight),
          Row(children: [
            const Text(AppStrings.progressDays),
            const SizedBox(width: 10),
            Expanded(
                child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7')),
                ButtonSegment(value: 30, label: Text('30')),
                ButtonSegment(value: 90, label: Text('90')),
              ],
              selected: {controller.rangeDays.value},
              onSelectionChanged: (value) =>
                  controller.selectRange(value.first),
            )),
          ]),
          if (entries.isEmpty)
            GlassCard(
              child: Column(children: [
                const Icon(Icons.monitor_weight_outlined,
                    color: AppPalette.emerald, size: 36),
                const Text(AppStrings.progressNoWeights),
                const SizedBox(height: 12),
                NeonButton(
                  onPressed: () => WeightEntrySheet.show(context),
                  label: AppStrings.logWeight,
                ),
              ]),
            )
          else ...[
            GlassCard(
              child: WeightChart(
                entries: entries,
                days: controller.rangeDays.value,
                endDate: controller.today,
                goalKg: goal,
              ),
            ),
            _statGrid(context, trend, controller.rangeDeltaKg, goal),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => WeightEntrySheet.show(context),
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.logWeight),
              ),
            ),
          ],
          const SectionHeader(title: AppStrings.progressStreaks),
          _streakCard(
              AppStrings.progressCalorieStreak, controller.calorieStreak),
          _streakCard(
              AppStrings.progressTrainingStreak, controller.trainingStreak),
          _streakCard(
              AppStrings.progressWeighInStreak, controller.weighInStreak),
          const SectionHeader(title: AppStrings.progressWeeklyRecap),
          _recapCard(recap, controller.recapDays, controller.recapTargetKcal,
              controller.recapStart),
          const SectionHeader(title: AppStrings.progressRecentWeights),
          if (controller.latestWeights.isEmpty)
            const GlassCard(child: Text(AppStrings.progressNoWeights))
          else
            for (final entry in controller.latestWeights)
              GlassCard(
                child: Row(children: [
                  const Icon(Icons.monitor_weight_outlined,
                      color: AppPalette.emerald),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry.kg.toStringAsFixed(1)} ${AppStrings.kg}'),
                        Text(
                            '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                            style: const TextStyle(color: AppPalette.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.edit,
                    onPressed: () =>
                        WeightEntrySheet.show(context, entry: entry),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: AppStrings.delete,
                    onPressed: () => _delete(context, entry),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ]),
              ),
          GlassCard(
            onTap: () => Get.toNamed(AppRoutes.history),
            child: const Row(children: [
              Icon(Icons.history, color: AppPalette.emerald),
              SizedBox(width: 10),
              Expanded(child: Text(AppStrings.history)),
              Icon(Icons.chevron_left_rounded),
            ]),
          ),
        ];
        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 28),
          children: [
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: entrance(rows[i], index: i),
              ),
          ],
        );
      });

  Widget _statGrid(
      BuildContext context, WeightTrend trend, double? delta, double? goal) {
    final rate = trend.weeklyRateKg;
    final eta = goal == null ? null : trend.etaFor(goal);
    final tiles = [
      StatTile(
          label: AppStrings.progressTrend,
          value: trend.trendKg?.toStringAsFixed(1) ?? '—',
          unit: AppStrings.kg),
      StatTile(
          label: AppStrings.progressRangeChange,
          value: delta == null
              ? '—'
              : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
          unit: AppStrings.kg),
      StatTile(
          label: AppStrings.progressWeeklyRate,
          value: rate == null
              ? '—'
              : '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(1)}',
          unit: AppStrings.kg),
      GestureDetector(
        onTap: goal == null ? () => GoalWeightSheet.show(context) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatTile(
              label: AppStrings.progressEta,
              value: eta == null ? '—' : '${eta.day}/${eta.month}'),
          if (goal == null)
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 16, top: 4),
              child: Text(AppStrings.progressSetGoal,
                  style: TextStyle(color: AppPalette.emerald)),
            ),
          if (eta != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, top: 4),
              child: Text('${eta.year}',
                  style: const TextStyle(color: AppPalette.muted)),
            ),
        ]),
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      // StatTile uses a large hero numeral; give dates and localized labels
      // the full row so they stay legible at narrow widths and large text.
      final width = constraints.maxWidth;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final tile in tiles) SizedBox(width: width, child: tile),
      ]);
    });
  }

  Widget _streakCard(String label, StreakResult streak) => GlassCard(
        child: Row(children: [
          Icon(Icons.local_fire_department_rounded,
              color: streak.current > 0 ? AppPalette.coral : AppPalette.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(streak.current == 0
                ? AppStrings.startStreak
                : AppStrings.progressCurrentStreak(streak.current)),
            Text(AppStrings.progressBestStreak(streak.best),
                style: const TextStyle(color: AppPalette.muted)),
          ]),
        ]),
      );

  Widget _recapCard(
      WeeklyRecap recap, List<DayLog> days, double? target, DateTime start) {
    final byKey = {for (final day in days) day.dateKey: day.consumedKcal};
    final maxKcal = math.max(
        1,
        math.max(target ?? 0,
            byKey.values.isEmpty ? 0 : byKey.values.reduce(math.max)));
    final chartMax = maxKcal * 1.1;
    final bars = <BarChartGroupData>[];
    for (var i = 0; i < 7; i++) {
      final date = DateTime(start.year, start.month, start.day + i);
      final kcal = byKey[DayLog.keyFor(date)] ?? 0;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: kcal == 0 ? chartMax * .025 : math.max(kcal, chartMax * .06),
          color: kcal == 0
              ? AppPalette.emerald.withValues(alpha: .2)
              : AppPalette.emerald,
          width: 16,
          borderRadius: BorderRadius.circular(4),
        ),
      ]));
    }
    return GlassCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            AppStrings.progressAvgKcal(recap.avgKcal.round(), target?.round())),
        Text(AppStrings.progressSessions(
            recap.sessionsDone, recap.sessionsPlanned)),
        Text(AppStrings.progressWeightDelta(recap.weightDeltaKg)),
        const SizedBox(height: 12),
        SizedBox(
            height: 112,
            child: Directionality(
              textDirection: TextDirection.ltr,
              // Time advances left to right, matching the weight chart.
              child: BarChart(BarChartData(
                minY: 0,
                maxY: chartMax,
                alignment: BarChartAlignment.spaceAround,
                barGroups: bars,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i > 6 || value != i) {
                        return const SizedBox.shrink();
                      }
                      final weekday =
                          DateTime(start.year, start.month, start.day + i)
                              .weekday;
                      return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(AppStrings.weekdayShort[weekday - 1],
                              style: const TextStyle(
                                  color: AppPalette.muted, fontSize: 10)));
                    },
                  )),
                ),
                extraLinesData: target == null
                    ? null
                    : ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: target,
                            color: AppPalette.lime,
                            strokeWidth: 1.5,
                            dashArray: [5, 4],
                          )
                        ],
                      ),
              )),
            )),
      ],
    ));
  }
}
