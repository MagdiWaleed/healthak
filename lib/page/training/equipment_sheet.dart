import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/profile_repository.dart';
import '../../domain/training/exercise.dart';
import '../../l10n/app_strings.dart';
import '../../service/session_controller.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';

/// The user's training equipment, used to filter exercises and templates.
/// Null on the profile means "never set" (treated as a full gym).
Set<Equipment> userEquipmentOrAll() => Get.isRegistered<SessionController>()
    ? Get.find<SessionController>().profile.value?.equipment ??
        Equipment.values.toSet()
    : Equipment.values.toSet();

/// True once the signed-in profile is available (the sheet saves into it).
bool profileLoaded() =>
    Get.isRegistered<SessionController>() &&
    Get.find<SessionController>().profile.value != null;

bool userHasSetEquipment() =>
    Get.isRegistered<SessionController>() &&
    Get.find<SessionController>().profile.value?.equipment != null;

String equipmentLabel(Equipment e) => AppStrings.equipmentLabels[e.name]!;

/// Short "عقلة · دمبل" summary of what an exercise needs.
String needsLabel(Set<Equipment> needs) {
  final real = needs.where((e) => e != Equipment.bodyweight).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return real.isEmpty
      ? equipmentLabel(Equipment.bodyweight)
      : real.map(equipmentLabel).join(' · ');
}

class EquipmentSheet extends StatefulWidget {
  const EquipmentSheet({super.key});

  static Future<void> show(BuildContext context) =>
      GlassSheet.show<void>(context, builder: (_) => const EquipmentSheet());

  @override
  State<EquipmentSheet> createState() => _EquipmentSheetState();
}

class _EquipmentSheetState extends State<EquipmentSheet> {
  static const _homeChoices = [
    Equipment.pullUpBar,
    Equipment.dumbbells,
    Equipment.bench,
    Equipment.barbell,
  ];
  late bool home;
  late Set<Equipment> picked;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final current = Get.find<SessionController>().profile.value?.equipment;
    home = current == null ||
        !current.containsAll({Equipment.cable, Equipment.machine});
    picked = current == null
        ? {Equipment.pullUpBar, Equipment.dumbbells}
        : current.intersection(_homeChoices.toSet());
  }

  Future<void> _save() async {
    final session = Get.find<SessionController>();
    final profile = session.profile.value;
    if (profile == null) return;
    setState(() => saving = true);
    try {
      final equipment =
          home ? {Equipment.bodyweight, ...picked} : Equipment.values.toSet();
      final updated =
          profile.copyWith(equipment: equipment, updatedAt: DateTime.now());
      await ProfileRepository().save(updated);
      session.profile.value = updated;
      if (!mounted) return;
      GlassSnackBar.show(context, AppStrings.equipmentSaved,
          tone: GlassSnackTone.success);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        GlassSnackBar.show(context, AppStrings.saveFailed,
            tone: GlassSnackTone.error);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => GlassSheet(
        title: AppStrings.whereTrain,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(AppStrings.equipmentHint,
                  style: TextStyle(color: AppPalette.muted)),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.home_outlined),
                      label: Text(AppStrings.trainHome)),
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.fitness_center),
                      label: Text(AppStrings.trainGym)),
                ],
                selected: {home},
                onSelectionChanged: (v) => setState(() => home = v.single),
              ),
              const SizedBox(height: 14),
              if (home)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in _homeChoices)
                    FilterChip(
                      label: Text(equipmentLabel(e)),
                      selected: picked.contains(e),
                      onSelected: (on) =>
                          setState(() => on ? picked.add(e) : picked.remove(e)),
                    ),
                ])
              else
                const Text(AppStrings.equipmentGymAll,
                    style: TextStyle(color: AppPalette.muted)),
              const SizedBox(height: 18),
              NeonButton(
                  label: AppStrings.save, loading: saving, onPressed: _save),
            ],
          ),
        ),
      );
}
