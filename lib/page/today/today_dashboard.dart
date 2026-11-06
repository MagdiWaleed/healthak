import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/day/day_log.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/activity_rings.dart';
import '../../ui/components/check_tile.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/ticker_number.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/celebration.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/motion_settings.dart';
import '../home/home_controller.dart';
import '../progress/weight_entry_sheet.dart';
import 'today_controller.dart';

class TodayDashboard extends StatelessWidget {
  const TodayDashboard(
      {required this.day,
      required this.controller,
      required this.readOnly,
      super.key});
  final DayLog day;
  final TodayController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final training = controller.trainingDay.value;
    final weight = controller.weightToday.value;
    final trend = controller.weightTrend.value;
    final target = day.targets.kcal;
    final eaten = day.consumedKcal;
    final protein = day.consumedTotals.protein;
    final proteinTarget = day.targets.macros.protein;
    final rings = [
      RingSpec(
          progress: target <= 0 ? 0 : eaten / target,
          color: AppPalette.ringCalories,
          label: AppStrings.todayEnergy),
      RingSpec(
          progress: training?.progress ?? 0,
          color: AppPalette.ringTraining,
          label: AppStrings.training),
      RingSpec(
          progress: proteinTarget <= 0 ? 0 : protein / proteinTarget,
          color: AppPalette.ringProtein,
          label: AppStrings.protein),
    ];
    final ring = SizedBox.square(
        dimension: 172,
        child: GoalCelebration(
          trigger: controller.goalCelebration.value,
          child: ActivityRings(
            rings: rings,
            size: 172,
            stroke: 13,
            center: Column(mainAxisSize: MainAxisSize.min, children: [
              TickerNumber(
                  value: (target - eaten).abs().round(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppPalette.text, fontWeight: FontWeight.w900)),
              Text(
                  eaten > target
                      ? AppStrings.aboveTarget
                      : AppStrings.remaining,
                  style:
                      const TextStyle(color: AppPalette.muted, fontSize: 11)),
            ]),
          ),
        ));
    final legend =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Legend(AppStrings.todayEnergy, '${eaten.round()}/${target.round()}',
          AppPalette.ringCalories),
      _Legend(
          AppStrings.training,
          '${training?.items.where((item) => item.done).length ?? 0}/${training?.items.length ?? 0}',
          AppPalette.ringTraining),
      _Legend(
          AppStrings.protein,
          '${protein.round()}/${proteinTarget.round()} ${AppStrings.grams}',
          AppPalette.ringProtein),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlassCard(child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(children: [
            Center(child: ring),
            const SizedBox(height: 12),
            legend
          ]);
        }
        return Row(children: [
          ring,
          const SizedBox(width: 12),
          Expanded(child: legend)
        ]);
      })),
      const SizedBox(height: 12),
      _Macros(day: day),
      const SizedBox(height: 18),
      const SectionHeader(title: AppStrings.currentWeight),
      const SizedBox(height: 8),
      GlassCard(
          child: Row(children: [
        const Icon(Icons.monitor_weight_outlined, color: AppPalette.emerald),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              weight == null
                  ? AppStrings.logWeightToday
                  : '${weight.kg.toStringAsFixed(1)} ${AppStrings.kg}',
              style: Theme.of(context).textTheme.titleMedium),
          if (trend?.deltaKg(7) case final delta?)
            Text(AppStrings.weightDelta7(delta),
                style: TextStyle(
                    color: _towardGoal(delta)
                        ? AppPalette.emerald
                        : AppPalette.coral)),
        ])),
        if (!readOnly)
          IconButton(
              tooltip: AppStrings.logWeightToday,
              onPressed: () => WeightEntrySheet.show(context, entry: weight),
              icon: const Icon(Icons.add_rounded)),
      ])),
      const SizedBox(height: 18),
      const SectionHeader(title: AppStrings.todayWorkout),
      const SizedBox(height: 8),
      GlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (training == null || training.isRestDay)
          const Text(AppStrings.restDay,
              style: TextStyle(color: AppPalette.muted))
        else ...[
          for (final item in training.items.take(4))
            CheckTile(
                key: ValueKey('training-${item.localId}'),
                title: item.nameAr,
                subtitle: AppStrings.setsReps(item.sets, item.reps),
                checked: item.done,
                enabled: !readOnly,
                onChanged: (_) => controller.toggleTraining(item.localId)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: training.progress,
              color: AppPalette.ringTraining,
              backgroundColor: AppPalette.outline),
        ],
        TextButton(
            onPressed: () => Get.find<HomeController>().goTo(HomeTab.training),
            child: const Text(AppStrings.viewFullWorkout)),
      ])),
    ]);
  }

  bool _towardGoal(double delta) {
    final goal = controller.goalWeightKg;
    final latest = controller.weightTrend.value?.latestKg;
    if (goal == null || latest == null) return delta < 0;
    return (goal - latest) * delta > 0;
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppPalette.muted, fontSize: 11))),
          Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppPalette.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)))
        ]),
      );
}

class _Macros extends StatelessWidget {
  const _Macros({required this.day});
  final DayLog day;
  @override
  Widget build(BuildContext context) {
    final eaten = day.consumedTotals;
    final target = day.targets.macros;
    final cards = [
      _Macro(AppStrings.protein, eaten.protein, target.protein,
          AppPalette.protein),
      _Macro(AppStrings.carbs, eaten.carbs, target.carbs, AppPalette.carbs),
      _Macro(AppStrings.fat, eaten.fat, target.fat, AppPalette.fat),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(children: [
          for (final card in cards)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: card)
        ]);
      }
      return Row(children: [
        for (final card in cards)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: card))
      ]);
    });
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.value, this.target, this.color);
  final String label;
  final double value;
  final double target;
  final Color color;
  @override
  Widget build(BuildContext context) => GlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        Text(AppStrings.macroAmount(value.round(), target.round()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
            tween: Tween(end: target <= 0 ? 0 : (value / target).clamp(0, 1)),
            duration: MotionSettings.duration(
                context, const Duration(milliseconds: 300)),
            builder: (_, progress, __) => LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                color: color,
                backgroundColor: AppPalette.outline)),
      ]));
}
