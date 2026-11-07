import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/training/arabic_normalize.dart';
import '../../domain/training/exercise.dart';
import '../../l10n/app_strings.dart';
import '../../ui/theme/app_colors.dart';
import 'equipment_sheet.dart';
import 'exercise_guide_sheet.dart';

class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({super.key});

  static Future<Exercise?> show(BuildContext context) =>
      showModalBottomSheet<Exercise>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const ExercisePickerSheet(),
      );

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  String query = '';

  /// Defaults to the user's equipment when they have set it up.
  bool onlyMine = userHasSetEquipment();

  bool _matches(Exercise e, String normalized, String lower) =>
      normalizeArabic(e.nameAr).contains(normalized) ||
      e.aliasesEn.any((a) => a.contains(lower));

  Future<void> _custom() async {
    final name = TextEditingController();
    var muscle = MuscleGroup.fullBody;
    final result = await showDialog<Exercise>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text(AppStrings.trainingCustom),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: AppStrings.trainingName)),
                    DropdownButtonFormField<MuscleGroup>(
                        initialValue: muscle,
                        decoration: const InputDecoration(
                            labelText: AppStrings.trainingMuscle),
                        items: [
                          for (final value in MuscleGroup.values)
                            DropdownMenuItem(
                                value: value, child: Text(muscleLabelAr(value)))
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => muscle = value);
                          }
                        }),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(AppStrings.assistantCancel)),
                    TextButton(
                        onPressed: () {
                          final text = name.text.trim();
                          if (text.isEmpty) return;
                          Navigator.pop(
                              context,
                              Exercise(
                                  id: const Uuid().v4(),
                                  nameAr: text,
                                  muscle: muscle,
                                  isCustom: true));
                        },
                        child: const Text(AppStrings.save)),
                  ],
                )));
    name.dispose();
    if (result != null && mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeArabic(query);
    final lower = query.trim().toLowerCase();
    final have = userEquipmentOrAll();
    final matches = kExerciseLibrary
        .where((e) => _matches(e, normalized, lower))
        .where((e) => !onlyMine || canDo(e, have))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: AppStrings.trainingSearch),
              onChanged: (value) => setState(() => query = value),
            )),
        if (userHasSetEquipment())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              ChoiceChip(
                  label: const Text(AppStrings.myEquipment),
                  selected: onlyMine,
                  onSelected: (_) => setState(() => onlyMine = true)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: const Text(AppStrings.allExercises),
                  selected: !onlyMine,
                  onSelected: (_) => setState(() => onlyMine = false)),
            ]),
          ),
        ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text(AppStrings.trainingCustom),
            onTap: _custom),
        Expanded(
            child: matches.isEmpty
                ? const Center(child: Text(AppStrings.trainingNoResults))
                : ListView(children: [
                    for (final group in MuscleGroup.values)
                      if (matches.any((e) => e.muscle == group)) ...[
                        Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16, 14, 16, 4),
                            child: Text(muscleLabelAr(group),
                                style:
                                    Theme.of(context).textTheme.titleMedium)),
                        for (final exercise
                            in matches.where((e) => e.muscle == group))
                          ListTile(
                              title: Text(exercise.nameAr),
                              trailing: IconButton(
                                  tooltip: AppStrings.exerciseGuide,
                                  icon: const Icon(Icons.info_outline,
                                      color: AppPalette.muted),
                                  onPressed: () => ExerciseGuideSheet.show(
                                      context, exercise.id)),
                              subtitle: Text(needsLabel(exercise.needs),
                                  style:
                                      const TextStyle(color: AppPalette.muted)),
                              onTap: () => Navigator.pop(context, exercise)),
                      ]
                  ])),
      ]),
    );
  }
}
