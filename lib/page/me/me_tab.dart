import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_routes.dart';
import '../../data/repositories/profile_repository.dart';
import '../../l10n/app_strings.dart';
import '../../service/auth_service.dart';
import '../../service/prefs_service.dart';
import '../../service/session_controller.dart';
import '../../ui/components/numeric_stepper.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/motion/motion.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/glass_tokens.dart';

class MeTab extends StatelessWidget {
  const MeTab({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.signOutTitle),
        content: const Text(AppStrings.signOutBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AppStrings.assistantCancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(AppStrings.signOut)),
        ],
      ),
    );
    if (confirmed == true) {
      await Get.find<AuthService>().signOut();
      await Get.find<PrefsService>().clearProfile();
      await Get.offAllNamed(AppRoutes.guest);
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final profile = Get.find<SessionController>().profile.value;
        final rows = <Widget>[
          Text(AppStrings.me,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    profile?.displayName.isNotEmpty == true
                        ? profile!.displayName
                        : AppStrings.me,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                    '${AppStrings.currentWeight}: ${_kgLabel(profile?.weightKg)}'),
                Text(
                    '${AppStrings.goalWeight}: ${_kgLabel(profile?.goalWeightKg)}'),
              ])),
          const SizedBox(height: AppSpacing.md),
          _MeRow(
              icon: Icons.person_outline,
              label: AppStrings.profileAndGoals,
              onTap: () => Get.toNamed(AppRoutes.profile),
              index: 0),
          _MeRow(
              icon: Icons.monitor_weight_outlined,
              label: AppStrings.goalWeight,
              onTap: () => GoalWeightSheet.show(context),
              index: 1),
          _MeRow(
              icon: Icons.calendar_month_outlined,
              label: AppStrings.history,
              onTap: () => Get.toNamed(AppRoutes.history),
              index: 2),
          _MeRow(
              icon: Icons.egg_alt_outlined,
              label: AppStrings.foodCatalog,
              onTap: () => Get.toNamed(AppRoutes.foods),
              index: 3),
          _MeRow(
              icon: Icons.payments_outlined,
              label: AppStrings.budget,
              onTap: () => Get.toNamed(AppRoutes.cost),
              index: 4),
          _MeRow(
              icon: Icons.logout,
              label: AppStrings.signOut,
              onTap: () => _confirmSignOut(context),
              index: 5,
              danger: true),
        ];
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          children: [
            for (var i = 0; i < rows.length; i++)
              Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: entrance(rows[i], index: i))
          ],
        );
      });
}

class _MeRow extends StatelessWidget {
  const _MeRow(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.index,
      this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int index;
  final bool danger;

  @override
  Widget build(BuildContext context) => GlassCard(
        specularAngleOffset: index * GlassTokens.listSpecularStepDeg,
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: danger ? AppPalette.danger : AppPalette.emerald),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: danger ? AppPalette.danger : AppPalette.text))),
          if (!danger)
            const Icon(Icons.chevron_left_rounded, color: AppPalette.muted),
        ]),
      );
}

class GoalWeightSheet extends StatefulWidget {
  const GoalWeightSheet({super.key});

  static Future<void> show(BuildContext context) =>
      GlassSheet.show<void>(context, builder: (_) => const GoalWeightSheet());

  @override
  State<GoalWeightSheet> createState() => _GoalWeightSheetState();
}

class _GoalWeightSheetState extends State<GoalWeightSheet> {
  double? kg;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    kg = Get.find<SessionController>().profile.value?.goalWeightKg;
  }

  Future<void> _save() async {
    final session = Get.find<SessionController>();
    final profile = session.profile.value;
    if (profile == null || kg == null) return;
    setState(() => saving = true);
    try {
      final updated =
          profile.copyWith(goalWeightKg: kg, updatedAt: DateTime.now());
      await ProfileRepository().save(updated);
      session.profile.value = updated;
      if (!mounted) return;
      GlassSnackBar.show(context, AppStrings.goalWeightSaved,
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
        title: AppStrings.goalWeight,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            NumericStepper(
              value: kg ?? 70,
              min: 25,
              max: 350,
              step: .1,
              format: (value) => value.toStringAsFixed(1),
              parse: (text) => double.tryParse(text.replaceAll('٫', '.')),
              onChanged: (value) => setState(() => kg = value),
            ),
            const SizedBox(height: 16),
            NeonButton(
                onPressed: saving ? null : _save,
                loading: saving,
                label: AppStrings.save),
          ]),
        ),
      );
}

/// "72.5 كجم", or just "غير محدد" -- never "غير محدد كجم".
String _kgLabel(double? kg) => kg == null
    ? AppStrings.notSet
    : '${kg.toStringAsFixed(1)} ${AppStrings.kg}';
