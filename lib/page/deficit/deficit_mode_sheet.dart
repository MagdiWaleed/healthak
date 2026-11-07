import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/profile_repository.dart';
import '../../domain/nutrition/energy.dart';
import '../../domain/profile/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../../service/session_controller.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';

class DeficitModeSheet extends StatefulWidget {
  const DeficitModeSheet({super.key});

  static Future<void> show(BuildContext context) =>
      GlassSheet.show<void>(context, builder: (_) => const DeficitModeSheet());

  @override
  State<DeficitModeSheet> createState() => _DeficitModeSheetState();
}

class _DeficitModeSheetState extends State<DeficitModeSheet> {
  late DeficitLevel level;
  late bool enabled;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final deficit = Get.find<SessionController>().profile.value?.deficit;
    level = deficit?.level ?? DeficitLevel.medium;
    enabled = deficit != null;
  }

  Future<void> _save() async {
    final session = Get.find<SessionController>();
    final profile = session.profile.value;
    if (profile == null) return;
    setState(() => saving = true);
    try {
      final updated = profile.copyWith(
        deficit: enabled
            ? DeficitMode(
                level: level,
                startedAt: profile.deficit?.startedAt ?? DateTime.now())
            : null,
        clearDeficit: !enabled,
      );
      await ProfileRepository().save(updated);
      session.profile.value = updated;
      if (mounted) Navigator.pop(context);
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
  Widget build(BuildContext context) {
    final profile = Get.find<SessionController>().profile.value;
    final bmr = profile == null
        ? 0.0
        : bmrMifflinStJeor(
            weightKg: profile.weightKg,
            heightCm: profile.heightCm,
            ageYears: profile.ageAt(DateTime.now()),
            sex: profile.sex);
    final maintenance =
        profile == null ? 0.0 : tdee(bmr: bmr, activity: profile.activityLevel);
    final budget = profile == null
        ? 0.0
        : NutritionTargets.deficit(
                weightKg: profile.weightKg,
                heightCm: profile.heightCm,
                ageYears: profile.ageAt(DateTime.now()),
                sex: profile.sex,
                activity: profile.activityLevel,
                level: level)
            .kcal;
    final floorApplied =
        profile != null && budget > maintenance * (1 - level.fraction) + .01;
    return GlassSheet(
      title: AppStrings.deficitMode,
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
            20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(AppStrings.deficitExplanation),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                title: const Text(AppStrings.deficitMode),
                value: enabled,
                onChanged: (value) => setState(() => enabled = value),
              ),
              const SizedBox(height: 8),
              SegmentedButton<DeficitLevel>(
                segments: const [
                  ButtonSegment(
                      value: DeficitLevel.light,
                      label: Text(AppStrings.deficitLightPercent)),
                  ButtonSegment(
                      value: DeficitLevel.medium,
                      label: Text(AppStrings.deficitMediumPercent)),
                  ButtonSegment(
                      value: DeficitLevel.strong,
                      label: Text(AppStrings.deficitStrongPercent)),
                ],
                selected: {level},
                onSelectionChanged: (selected) =>
                    setState(() => level = selected.first),
              ),
              const SizedBox(height: 12),
              Text(
                  AppStrings.deficitPreview(
                      maintenance.round(), budget.round()),
                  style: Theme.of(context).textTheme.titleMedium),
              if (floorApplied)
                const Text(AppStrings.deficitFloorNote,
                    style: TextStyle(color: AppPalette.coral)),
              const SizedBox(height: 18),
              NeonButton(
                  label: AppStrings.save,
                  loading: saving,
                  onPressed: saving ? null : _save),
            ]),
      ),
    );
  }
}
