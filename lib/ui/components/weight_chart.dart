import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/body/body_weight.dart';
import '../../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/motion_settings.dart';

class WeightChart extends StatelessWidget {
  const WeightChart({
    required this.entries,
    required this.days,
    required this.endDate,
    this.goalKg,
    super.key,
  });

  final List<BodyWeightEntry> entries;
  final int days;
  final DateTime endDate;
  final double? goalKg;

  @override
  Widget build(BuildContext context) {
    final trend = WeightTrend(entries);
    if (trend.entries.isEmpty) return const SizedBox.shrink();
    final start = DateTime(endDate.year, endDate.month, endDate.day - days + 1);
    double xOf(BodyWeightEntry entry) =>
        DateTime.utc(entry.date.year, entry.date.month, entry.date.day)
            .difference(DateTime.utc(start.year, start.month, start.day))
            .inDays
            .toDouble();
    final raw = [
      for (final entry in trend.entries) FlSpot(xOf(entry), entry.kg)
    ];
    final smooth = [
      for (var i = 0; i < trend.entries.length; i++)
        FlSpot(xOf(trend.entries[i]), trend.ema[i]),
    ];
    final values = <double>[
      ...trend.entries.map((e) => e.kg),
      if (goalKg != null) goalKg!,
    ];
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final padding = math.max(1.0, (high - low) * .18);
    final minY = low - padding;
    final maxY = high + padding;

    // Dates must advance left to right even though the surrounding Arabic UI
    // is RTL; reversing time would make the weight trajectory misleading.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: math.max(1, days - 1).toDouble(),
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppPalette.outline, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 25,
                  interval: math.max(1, (days - 1) / 3).toDouble(),
                  getTitlesWidget: (value, meta) {
                    final date = DateTime(
                        start.year, start.month, start.day + value.round());
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text('${date.day}/${date.month}',
                          style: const TextStyle(
                              color: AppPalette.muted, fontSize: 10)),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: goalKg == null
                ? null
                : ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: goalKg!,
                      color: AppPalette.lime,
                      strokeWidth: 1.5,
                      dashArray: [5, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        style: const TextStyle(
                            color: AppPalette.lime, fontSize: 10),
                        labelResolver: (_) => AppStrings.progressGoalLine,
                      ),
                    ),
                  ]),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppPalette.raised,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    spot.barIndex == 0
                        ? LineTooltipItem(
                            '${trend.entries[spot.spotIndex].date.day}/${trend.entries[spot.spotIndex].date.month}/${trend.entries[spot.spotIndex].date.year}\n${spot.y.toStringAsFixed(1)} ${AppStrings.kg}',
                            const TextStyle(color: AppPalette.text),
                          )
                        : null,
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: raw,
                color: Colors.transparent,
                barWidth: 0,
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 3.5,
                    color: AppPalette.text,
                    strokeWidth: 1.5,
                    strokeColor: AppPalette.emerald,
                  ),
                ),
              ),
              LineChartBarData(
                spots: smooth,
                color: AppPalette.emerald,
                barWidth: 3,
                isCurved: smooth.length > 2,
                preventCurveOverShooting: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppPalette.emerald.withValues(alpha: .24),
                      AppPalette.emerald.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: MotionSettings.duration(
              context, const Duration(milliseconds: 280)),
        ),
      ),
    );
  }
}
