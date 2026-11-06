import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/workout_plan_repository.dart';
import '../../domain/training/exercise.dart';
import '../../domain/training/training_plan_edit.dart';
import '../../domain/training/workout_plan_item.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/components/numeric_stepper.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/theme/app_colors.dart';
import 'exercise_picker_sheet.dart';

class PlanEditorController extends GetxController {
  PlanEditorController({required this.uid, WorkoutPlanRepository? repository})
      : _repository = repository ?? WorkoutPlanRepository(uid: uid);
  final String uid;
  final WorkoutPlanRepository _repository;
  final items = <WorkoutPlanItem>[].obs;
  final originalIds = <String>{};
  final weekday = 1.obs;
  final loading = true.obs;
  final saving = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final data = await _repository.getAll();
      originalIds.addAll(data.map((e) => e.id));
      items.assignAll(data);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  List<WorkoutPlanItem> forDay(int day) =>
      items.where((e) => e.daysOfWeek.contains(day)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  void replace(WorkoutPlanItem item) {
    final index = items.indexWhere((e) => e.id == item.id);
    if (index >= 0) items[index] = item.copyWith(updatedAt: DateTime.now());
  }

  void add(Exercise exercise) {
    final now = DateTime.now();
    items.add(WorkoutPlanItem(
        id: const Uuid().v4(),
        exerciseId: exercise.id,
        nameAr: exercise.nameAr,
        muscle: exercise.muscle,
        sets: 3,
        reps: 10,
        daysOfWeek: {weekday.value},
        order: forDay(weekday.value).length,
        createdAt: now,
        updatedAt: now));
  }

  void reorder(int oldIndex, int newIndex) => items.assignAll(
      reorderWorkoutDay(items.toList(), weekday.value, oldIndex, newIndex));

  void remove(String id) => items.removeWhere((e) => e.id == id);

  void copyTo(Set<int> days) {
    final source = forDay(weekday.value);
    final now = DateTime.now();
    for (final day in days) {
      for (final item in source) {
        items.add(WorkoutPlanItem(
            id: const Uuid().v4(),
            exerciseId: item.exerciseId,
            nameAr: item.nameAr,
            muscle: item.muscle,
            sets: item.sets,
            reps: item.reps,
            daysOfWeek: {day},
            order: forDay(day).length,
            active: item.active,
            createdAt: now,
            updatedAt: now));
      }
    }
  }

  void template(StarterTemplate template) => items.assignAll(
      expandStarterTemplate(template, DateTime.now(), const Uuid().v4));

  Future<bool> save() async {
    if (saving.value) return false;
    saving.value = true;
    error.value = null;
    try {
      final kept = items.map((e) => e.id).toSet();
      await _repository.saveAll(items, deleteIds: originalIds.difference(kept));
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      saving.value = false;
    }
  }
}

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  @override
  void initState() {
    super.initState();
    if (Get.arguments == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _templates(context, Get.find<PlanEditorController>());
      });
    }
  }

  Future<void> _add(
      BuildContext context, PlanEditorController controller) async {
    final exercise = await ExercisePickerSheet.show(context);
    if (exercise != null) controller.add(exercise);
  }

  Future<void> _delete(
      BuildContext context, PlanEditorController controller, String id) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text(AppStrings.trainingDeleteConfirm),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(AppStrings.assistantCancel)),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(AppStrings.delete)),
                ]));
    if (yes == true) controller.remove(id);
  }

  Future<void> _copy(
      BuildContext context, PlanEditorController controller) async {
    final days = <int>{};
    final result = await showDialog<Set<int>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: const Text(AppStrings.trainingSelectDays),
                  content: Wrap(spacing: 5, children: [
                    for (var day = 1; day <= 7; day++)
                      if (day != controller.weekday.value)
                        FilterChip(
                            label: Text(AppStrings.weekdayShort[day - 1]),
                            selected: days.contains(day),
                            onSelected: (selected) => setState(() =>
                                selected ? days.add(day) : days.remove(day))),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(AppStrings.assistantCancel)),
                    TextButton(
                        onPressed: () => Navigator.pop(context, days),
                        child: const Text(AppStrings.trainingCopyDays)),
                  ],
                )));
    if (result != null) controller.copyTo(result);
  }

  Future<void> _templates(
      BuildContext context, PlanEditorController controller) async {
    final template = await showModalBottomSheet<StarterTemplate>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final entry in const [
                (StarterTemplate.pushPullLegs, AppStrings.trainingPushPullLegs),
                (StarterTemplate.upperLower, AppStrings.trainingUpperLower),
                (StarterTemplate.fullBodyThree, AppStrings.trainingFullBody),
              ])
                ListTile(
                    title: Text(entry.$2),
                    onTap: () => Navigator.pop(context, entry.$1)),
            ])));
    if (template == null || !context.mounted) return;
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text(AppStrings.trainingApplyTemplate),
                content: const Text(AppStrings.trainingReplaceWarning),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(AppStrings.assistantCancel)),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(AppStrings.assistantConfirm)),
                ]));
    if (yes == true) controller.template(template);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlanEditorController>();
    return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.trainingPlanEdit)),
        body: Obx(() {
          final day = controller.weekday.value;
          final list = controller.forDay(day);
          if (controller.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(children: [
            SizedBox(
                height: 54,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (var i = 1; i <= 7; i++)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                            label: Text(AppStrings.weekdayShort[i - 1]),
                            selected: i == day,
                            onSelected: (_) => controller.weekday.value = i))
                ])),
            Expanded(
                child: ReorderableListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: list.length,
                    onReorder: controller.reorder,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return GlassCard(
                          key: ValueKey(item.id),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(item.nameAr,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium)),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          _delete(context, controller, item.id))
                                ]),
                                Text(muscleLabelAr(item.muscle)),
                                Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const Text(AppStrings.trainingSets),
                                      NumericStepper(
                                          value: item.sets.toDouble(),
                                          step: 1,
                                          min: 1,
                                          max: 20,
                                          format: (v) => '${v.round()}',
                                          parse: (v) => double.tryParse(v),
                                          onChanged: (v) => controller.replace(
                                              item.copyWith(sets: v.round()))),
                                      const Text(AppStrings.trainingReps),
                                      NumericStepper(
                                          value: item.reps.toDouble(),
                                          step: 1,
                                          min: 1,
                                          max: 100,
                                          format: (v) => '${v.round()}',
                                          parse: (v) => double.tryParse(v),
                                          onChanged: (v) => controller.replace(
                                              item.copyWith(reps: v.round()))),
                                    ]),
                                SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.active
                                        ? AppStrings.trainingPause
                                        : AppStrings.trainingResume),
                                    value: item.active,
                                    onChanged: (v) => controller
                                        .replace(item.copyWith(active: v))),
                                Wrap(spacing: 4, children: [
                                  for (var i = 1; i <= 7; i++)
                                    FilterChip(
                                        label: Text(
                                            AppStrings.weekdayShort[i - 1]),
                                        selected: item.daysOfWeek.contains(i),
                                        onSelected: (selected) {
                                          final days = {...item.daysOfWeek};
                                          if (selected) {
                                            days.add(i);
                                          } else if (days.length > 1) {
                                            days.remove(i);
                                          }
                                          controller.replace(
                                              item.copyWith(daysOfWeek: days));
                                        })
                                ]),
                              ]));
                    })),
            if (controller.error.value case final error?)
              Text(error, style: const TextStyle(color: AppPalette.coral)),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                        onPressed: () => _add(context, controller),
                        child: const Text(AppStrings.trainingAddExercise)),
                    OutlinedButton(
                        onPressed: () => _copy(context, controller),
                        child: const Text(AppStrings.trainingCopyDays)),
                    OutlinedButton(
                        onPressed: () => _templates(context, controller),
                        child: const Text(AppStrings.trainingTemplates)),
                  ]),
                  const SizedBox(height: 8),
                  NeonButton(
                      label: AppStrings.save,
                      loading: controller.saving.value,
                      onPressed: () async {
                        if (await controller.save() && context.mounted) {
                          Navigator.pop(context);
                        }
                      }),
                ])),
          ]);
        }));
  }
}
