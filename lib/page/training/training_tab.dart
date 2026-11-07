import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/components/shimmer_box.dart';

import '../../domain/day/day_log.dart';
import '../../domain/training/exercise.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/activity_rings.dart';
import '../../ui/components/check_tile.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/stat_tile.dart';
import '../../ui/motion/celebration.dart';
import '../../ui/motion/motion.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/theme/app_colors.dart';
import '../today/today_tab.dart' show DayChip;
import '../../app/app_routes.dart';
import 'exercise_picker_sheet.dart';
import 'training_controller.dart';

class TrainingTab extends StatefulWidget {
  const TrainingTab({super.key});

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  late final TrainingController controller = Get.find<TrainingController>();
  Worker? _celebrationWorker;

  @override
  void initState() {
    super.initState();
    _celebrationWorker = ever<int>(controller.celebration, (_) {
      if (mounted) Celebration.show(context);
    });
  }

  @override
  void dispose() {
    _celebrationWorker?.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final exercise = await ExercisePickerSheet.show(context);
    if (exercise != null) await controller.addOneOff(exercise);
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final selected = controller.selectedDate.value;
        final day = controller.day.value;
        final monday = selected.subtract(Duration(days: selected.weekday - 1));
        final today = controller.today;
        final readOnly = !controller.canEdit;
        return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 110),
            children: [
              SectionHeader(
                  title: AppStrings.training,
                  actionText: AppStrings.trainingPlanEdit,
                  onAction: () => Get.toNamed(AppRoutes.trainingEditor,
                      arguments: selected.weekday)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final width = (constraints.maxWidth - 18) / 7;
                return Row(children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    DayChip(
                        date: monday.add(Duration(days: i)),
                        width: width,
                        selected:
                            DayLog.keyFor(monday.add(Duration(days: i))) ==
                                DayLog.keyFor(selected),
                        isToday: DayLog.keyFor(monday.add(Duration(days: i))) ==
                            DayLog.keyFor(today),
                        logged: controller.recentDays.any((d) =>
                            d.dateKey ==
                            DayLog.keyFor(monday.add(Duration(days: i)))),
                        onTap: monday.add(Duration(days: i)).isAfter(
                                DateTime(today.year, today.month, today.day))
                            ? null
                            : () => controller
                                .selectDate(monday.add(Duration(days: i)))),
                  ]
                ]);
              }),
              if (readOnly) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Text(AppStrings.historyReadOnly)),
                  TextButton(
                      onPressed: controller.toggleEditingPast,
                      child: Text(controller.editingPast.value
                          ? AppStrings.done
                          : AppStrings.edit)),
                ]),
              ] else if (!controller.isToday)
                Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                        onPressed: controller.toggleEditingPast,
                        child: const Text(AppStrings.done))),
              const SizedBox(height: 20),
              Center(
                  child: ActivityRings(
                      size: 196,
                      stroke: 18,
                      rings: [
                        RingSpec(
                            progress: day?.progress ?? 0,
                            color: AppPalette.emerald,
                            label: AppStrings.training)
                      ],
                      center: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (day?.isRestDay ?? true)
                          Text(AppStrings.trainingRest,
                              style: Theme.of(context).textTheme.titleMedium)
                        else ...[
                          Text('${((day?.progress ?? 0) * 100).round()}%',
                              style: Theme.of(context).textTheme.headlineLarge),
                          Text(AppStrings.trainingProgress(
                              controller.doneCount, day!.items.length)),
                        ],
                      ]))),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                    child: StatTile(
                        label: AppStrings.trainingDoneTotal,
                        value: day?.isRestDay ?? true
                            ? AppStrings.trainingRest
                            : AppStrings.trainingProgress(
                                controller.doneCount, day!.items.length))),
                const SizedBox(width: 6),
                Expanded(
                    child: StatTile(
                        label: AppStrings.trainingTotalSets,
                        value: '${controller.totalSets}')),
                const SizedBox(width: 6),
                Expanded(
                    child: StatTile(
                        label: AppStrings.trainingStreak,
                        value: controller.streak == 0
                            ? AppStrings.startStreak
                            : '${controller.streak}')),
              ]),
              const SizedBox(height: 22),
              SectionHeader(
                  title: AppStrings.todayWorkout,
                  actionText: readOnly ? null : AppStrings.trainingAddExercise,
                  onAction: readOnly ? null : _pick),
              if (controller.error.value case final error?)
                Text(error, style: const TextStyle(color: AppPalette.coral)),
              if (controller.loading.value && day == null)
                const Column(children: [
                  ShimmerBox(height: 80),
                  SizedBox(height: 12),
                  ShimmerBox(height: 80),
                  SizedBox(height: 12),
                  ShimmerBox(height: 80),
                ])
              else if (controller.plan.isEmpty && (day?.items.isEmpty ?? true))
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(children: [
                      const Icon(Icons.fitness_center_outlined,
                          size: 56, color: AppPalette.emerald),
                      const SizedBox(height: 10),
                      const Text(AppStrings.trainingRest),
                      const SizedBox(height: 14),
                      NeonButton(
                          label: AppStrings.trainingStart,
                          onPressed: () => Get.toNamed(AppRoutes.trainingEditor,
                                  arguments: (
                                    weekday: selected.weekday,
                                    showTemplates: true
                                  ))),
                    ]))
              else if (day?.items.isEmpty ?? true)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text(AppStrings.trainingRest)))
              else
                for (var i = 0; i < day!.items.length; i++)
                  entrance(
                      Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: GlassCard(
                              padding: EdgeInsets.zero,
                              child: CheckTile(
                                  key: ValueKey(day.items[i].localId),
                                  title: day.items[i].nameAr,
                                  subtitle: AppStrings.setsReps(
                                      day.items[i].sets, day.items[i].reps),
                                  trailing: Chip(
                                      label: Text(
                                          muscleLabelAr(day.items[i].muscle),
                                          style: const TextStyle(fontSize: 10)),
                                      visualDensity: VisualDensity.compact),
                                  checked: day.items[i].done,
                                  enabled: !readOnly,
                                  onChanged: (_) => controller
                                      .toggle(day.items[i].localId)))),
                      index: i),
            ]);
      });
}
