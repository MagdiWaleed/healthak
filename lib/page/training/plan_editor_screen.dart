import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/workout_plan_repository.dart';
import '../../domain/training/exercise.dart';
import '../../domain/training/training_plan_edit.dart';
import '../../domain/training/workout_plan_item.dart';
import '../../domain/training/workout_templates.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/components/numeric_stepper.dart';
import '../../ui/components/shimmer_box.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';
import 'equipment_sheet.dart';
import 'exercise_picker_sheet.dart';
import 'template_picker_sheet.dart';

/// Week order shown to the user: Saturday first, the usual week start here.
const kWeekOrder = [6, 7, 1, 2, 3, 4, 5];

class PlanEditorController extends GetxController {
  PlanEditorController({required this.uid, WorkoutPlanRepository? repository})
      : _repository = repository ?? WorkoutPlanRepository(uid: uid);
  final String uid;
  final WorkoutPlanRepository _repository;
  final items = <WorkoutPlanItem>[].obs;
  final originalIds = <String>{};

  /// The day being edited; null shows the week overview.
  final selectedDay = RxnInt();

  /// The weekday the user came from (highlighted in the overview).
  final weekday = 1.obs;
  final loading = true.obs;
  final saving = false.obs;
  final dirty = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    if (arguments is int && arguments >= 1 && arguments <= 7) {
      weekday.value = arguments;
    } else if (arguments is ({int weekday, bool showTemplates})) {
      weekday.value = arguments.weekday;
    }
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

  int get _day => selectedDay.value ?? weekday.value;

  List<WorkoutPlanItem> forDay(int day) =>
      items.where((e) => e.daysOfWeek.contains(day)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  /// "صدر · ظهر" from the day's active exercises, most frequent first.
  List<MuscleGroup> focusOf(int day) {
    final counts = <MuscleGroup, int>{};
    for (final item in forDay(day).where((e) => e.active)) {
      counts[item.muscle] = (counts[item.muscle] ?? 0) + 1;
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(3).toList();
  }

  void replace(WorkoutPlanItem item) {
    final index = items.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      items[index] = item.copyWith(updatedAt: DateTime.now());
      dirty.value = true;
    }
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
        daysOfWeek: {_day},
        order: forDay(_day).length,
        createdAt: now,
        updatedAt: now));
    dirty.value = true;
  }

  void reorder(int oldIndex, int newIndex) {
    items
        .assignAll(reorderWorkoutDay(items.toList(), _day, oldIndex, newIndex));
    dirty.value = true;
  }

  void remove(String id) {
    items.removeWhere((e) => e.id == id);
    dirty.value = true;
  }

  void copyTo(Set<int> days) {
    final source = forDay(_day);
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
            loadKg: item.loadKg,
            daysOfWeek: {day},
            order: forDay(day).length,
            active: item.active,
            createdAt: now,
            updatedAt: now));
      }
    }
    dirty.value = true;
  }

  /// Replaces only [days]; every other day keeps its exercises.
  void applyTemplate(WorkoutTemplate template, List<int> days) {
    final now = DateTime.now();
    final incoming = expandTemplate(template, days, now, const Uuid().v4);
    final result =
        applyTemplateToDays(items.toList(), incoming, days.toSet(), now);
    items.assignAll(result.plan);
    dirty.value = true;
  }

  Future<bool> save() async {
    if (saving.value) return false;
    saving.value = true;
    error.value = null;
    try {
      final kept = items.map((e) => e.id).toSet();
      await _repository.saveAll(items, deleteIds: originalIds.difference(kept));
      originalIds
        ..clear()
        ..addAll(kept);
      dirty.value = false;
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      saving.value = false;
    }
  }
}

String _setsReps(WorkoutPlanItem item) =>
    AppStrings.setsReps(item.sets, item.reps, loadKg: item.loadKg);

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  PlanEditorController get c => Get.find<PlanEditorController>();

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final wantsTemplates = args == true ||
        (args is ({int weekday, bool showTemplates}) && args.showTemplates);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // First visit: ask once where they train, so suggestions fit.
      if (!userHasSetEquipment() && profileLoaded()) {
        await EquipmentSheet.show(context);
      }
      if (wantsTemplates && mounted) await _templates(context);
    });
  }

  Future<void> _add(BuildContext context) async {
    final exercise = await ExercisePickerSheet.show(context);
    if (exercise != null) c.add(exercise);
  }

  Future<void> _templates(BuildContext context) async {
    final choice = await TemplatePickerSheet.show(context);
    if (choice == null || !context.mounted) return;
    final names = choice.days.map((d) => AppStrings.weekdays[d - 1]).join('، ');
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text(AppStrings.trainingApplyTemplate),
                content: Text(AppStrings.templateReplaceDays(names)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(AppStrings.assistantCancel)),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(AppStrings.assistantConfirm)),
                ]));
    if (yes == true) {
      c.applyTemplate(choice.template, choice.days);
      c.selectedDay.value = null;
    }
  }

  Future<void> _copy(BuildContext context) async {
    final days = <int>{};
    final result = await showDialog<Set<int>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: const Text(AppStrings.trainingSelectDays),
                  content: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final day in kWeekOrder)
                      if (day != c.selectedDay.value)
                        FilterChip(
                            label: Text(AppStrings.weekdays[day - 1]),
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
    if (result != null && result.isNotEmpty) c.copyTo(result);
  }

  Future<void> _edit(BuildContext context, WorkoutPlanItem item) async {
    final result = await GlassSheet.show<Object>(context,
        builder: (_) => _ExerciseEditSheet(item: item));
    if (result is WorkoutPlanItem) c.replace(result);
    if (result == #delete) c.remove(item.id);
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text(AppStrings.unsavedTitle),
              content: const Text(AppStrings.unsavedBody),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, 'keep'),
                    child: const Text(AppStrings.keepEditing)),
                TextButton(
                    onPressed: () => Navigator.pop(context, 'discard'),
                    child: const Text(AppStrings.discard,
                        style: TextStyle(color: AppPalette.coral))),
                TextButton(
                    onPressed: () => Navigator.pop(context, 'save'),
                    child: const Text(AppStrings.save)),
              ],
            ));
    if (choice == 'discard') return true;
    if (choice == 'save') return c.save();
    return false;
  }

  Future<void> _back(BuildContext context) async {
    if (c.selectedDay.value != null) {
      c.selectedDay.value = null;
      return;
    }
    if (!c.dirty.value || await _confirmLeave(context)) {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final day = c.selectedDay.value;
        return PopScope(
          canPop: day == null && !c.dirty.value,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back(context);
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                  icon: const BackButtonIcon(),
                  onPressed: () => _back(context)),
              title: Text(day == null
                  ? AppStrings.myWeekPlan
                  : AppStrings.weekdays[day - 1]),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (v) => switch (v) {
                    'templates' => _templates(context),
                    'copy' => _copy(context),
                    'equipment' => EquipmentSheet.show(context),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'templates',
                        child: Text(AppStrings.trainingTemplates)),
                    if (day != null && c.forDay(day).isNotEmpty)
                      const PopupMenuItem(
                          value: 'copy',
                          child: Text(AppStrings.trainingCopyDays)),
                    const PopupMenuItem(
                        value: 'equipment',
                        child: Text(AppStrings.myEquipment)),
                  ],
                ),
              ],
            ),
            body: c.loading.value
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(children: [
                      ShimmerBox(height: 64),
                      SizedBox(height: 10),
                      ShimmerBox(height: 64),
                      SizedBox(height: 10),
                      ShimmerBox(height: 64),
                    ]),
                  )
                : Column(children: [
                    Expanded(
                        child: day == null
                            ? _week(context)
                            : _dayView(context, day)),
                    if (c.error.value case final error?)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(error,
                            style: const TextStyle(color: AppPalette.coral)),
                      ),
                    _bottomBar(context, day),
                  ]),
          ),
        );
      });

  Widget _week(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          for (final d in kWeekOrder) _weekRow(context, d),
        ],
      );

  Widget _weekRow(BuildContext context, int d) {
    final list = c.forDay(d);
    final rest = list.isEmpty;
    final focus = c.focusOf(d).map(muscleLabelAr).join(' · ');
    final highlight = d == c.weekday.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => c.selectedDay.value = d,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rest
                    ? AppPalette.raised
                    : AppPalette.emerald.withValues(alpha: .16),
                border: highlight
                    ? Border.all(color: AppPalette.emerald, width: 1.5)
                    : null,
              ),
              child: Text(AppStrings.weekdayShort[d - 1],
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: rest ? AppPalette.muted : AppPalette.emerald)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.weekdays[d - 1],
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    rest
                        ? AppStrings.restDayShort
                        : '${focus.isEmpty ? '' : '$focus · '}${AppStrings.exercisesCount(list.length)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppPalette.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppPalette.muted),
          ]),
        ),
      ),
    );
  }

  Widget _dayView(BuildContext context, int day) {
    final list = c.forDay(day);
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.self_improvement,
                size: 48, color: AppPalette.muted),
            const SizedBox(height: 10),
            const Text(AppStrings.trainingEmptyEditorDay,
                style: TextStyle(color: AppPalette.muted)),
            const SizedBox(height: 14),
            TextButton.icon(
                onPressed: () => _templates(context),
                icon: const Icon(Icons.auto_awesome),
                label: const Text(AppStrings.trainingTemplates)),
          ]),
        ),
      );
    }
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: list.length,
      onReorder: c.reorder,
      itemBuilder: (context, index) {
        final item = list[index];
        return Padding(
          key: ValueKey(item.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: item.active ? 1 : .5,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _edit(context, item),
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child:
                          Icon(Icons.drag_indicator, color: AppPalette.muted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.nameAr,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          item.active
                              ? muscleLabelAr(item.muscle)
                              : '${muscleLabelAr(item.muscle)} · ${AppStrings.trainingPaused}',
                          style: const TextStyle(
                              color: AppPalette.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppPalette.emerald.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(_setsReps(item),
                        style: const TextStyle(
                            color: AppPalette.emerald,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar(BuildContext context, int? day) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            if (day != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _add(context),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder()),
                  icon: const Icon(Icons.add),
                  label: const Text(AppStrings.trainingAddExercise),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: NeonButton(
                label: AppStrings.save,
                loading: c.saving.value,
                onPressed: c.dirty.value
                    ? () async {
                        if (await c.save() && context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    : null,
              ),
            ),
          ]),
        ),
      );
}

/// Everything about one exercise, in one calm sheet instead of inline.
class _ExerciseEditSheet extends StatefulWidget {
  const _ExerciseEditSheet({required this.item});
  final WorkoutPlanItem item;

  @override
  State<_ExerciseEditSheet> createState() => _ExerciseEditSheetState();
}

class _ExerciseEditSheetState extends State<_ExerciseEditSheet> {
  late WorkoutPlanItem item = widget.item;

  Widget _row(String label, Widget control) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          control,
        ]),
      );

  @override
  Widget build(BuildContext context) => GlassSheet(
        title: item.nameAr,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(muscleLabelAr(item.muscle),
                  style: const TextStyle(color: AppPalette.muted)),
              const SizedBox(height: 8),
              _row(
                  AppStrings.trainingSets,
                  NumericStepper(
                      value: item.sets.toDouble(),
                      step: 1,
                      min: 1,
                      max: 20,
                      format: (v) => '${v.round()}',
                      parse: double.tryParse,
                      onChanged: (v) => setState(
                          () => item = item.copyWith(sets: v.round())))),
              _row(
                  AppStrings.trainingReps,
                  NumericStepper(
                      value: item.reps.toDouble(),
                      step: 1,
                      min: 1,
                      max: 100,
                      format: (v) => '${v.round()}',
                      parse: double.tryParse,
                      onChanged: (v) => setState(
                          () => item = item.copyWith(reps: v.round())))),
              _row(
                  AppStrings.trainingLoad,
                  NumericStepper(
                      value: item.loadKg ?? 0,
                      step: 1,
                      min: 0,
                      max: 200,
                      format: (v) =>
                          v <= 0 ? AppStrings.trainingNoLoad : '${v.round()}',
                      parse: double.tryParse,
                      onChanged: (v) => setState(() => item = v <= 0
                          ? item.copyWith(clearLoad: true)
                          : item.copyWith(loadKg: v)))),
              const SizedBox(height: 6),
              const Text(AppStrings.trainingDays,
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final d in kWeekOrder)
                  FilterChip(
                    label: Text(AppStrings.weekdayShort[d - 1]),
                    selected: item.daysOfWeek.contains(d),
                    onSelected: (on) {
                      final days = {...item.daysOfWeek};
                      if (on) {
                        days.add(d);
                      } else if (days.length > 1) {
                        days.remove(d);
                      }
                      setState(() => item = item.copyWith(daysOfWeek: days));
                    },
                  ),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.trainingPlanActive),
                value: item.active,
                onChanged: (v) =>
                    setState(() => item = item.copyWith(active: v)),
              ),
              const SizedBox(height: 6),
              Row(children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop<Object>(context, #delete),
                  icon:
                      const Icon(Icons.delete_outline, color: AppPalette.coral),
                  label: const Text(AppStrings.delete,
                      style: TextStyle(color: AppPalette.coral)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeonButton(
                      label: AppStrings.done,
                      onPressed: () => Navigator.pop<Object>(context, item)),
                ),
              ]),
            ],
          ),
        ),
      );
}
