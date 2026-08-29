import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_routes.dart';
import '../../domain/nutrition/energy.dart';
import '../../service/auth_service.dart';
import '../../service/prefs_service.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/components/glass_chip.dart';
import '../../ui/components/energy_breakdown_card.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import 'profile_controller.dart';

/// Edit body stats, activity, and goal, with a live before/after preview of
/// the day's target -- and, at the bottom, delete-account behind a typed
/// confirmation rather than the legacy screen's none at all.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController controller = ProfileController();

  @override
  void initState() {
    super.initState();
    // See the identical note in my_meals_tab.dart / meal_editor_screen.dart:
    // this controller is plain-constructed, not Get.put, so GetX never calls
    // onInit() on its own. Without this, the form fields never fill in from
    // the current profile -- they'd just sit blank.
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await controller.save();
    if (!mounted) return;
    GlassSnackBar.show(
      context,
      ok ? 'تم حفظ التغييرات' : (controller.error.value ?? 'تعذر الحفظ'),
      tone: ok ? GlassSnackTone.success : GlassSnackTone.error,
    );
    // A successful save leaves nothing to do here. Staying on a form that has
    // just been committed reads as "it didn't take" -- everywhere else in the
    // app (the meal editor, every sheet) a confirmed action closes what it
    // was performed in. A failure keeps the screen so the input is not lost.
    if (ok) Get.back();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;

    final ok = await controller.deleteAccount();
    if (!mounted) return;
    if (!ok) {
      GlassSnackBar.show(
        context,
        controller.error.value ?? 'تعذر حذف الحساب',
        tone: GlassSnackTone.error,
      );
      return;
    }
    await Get.find<AuthService>().signOut();
    await Get.find<PrefsService>().clearProfile();
    await Get.offAllNamed(AppRoutes.guest);
  }

  @override
  Widget build(BuildContext context) => GlassScaffold(
        appBar: AppBar(title: const Text('حسابي')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 88, AppSpacing.md, AppSpacing.xxl),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('البيانات الجسدية',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: controller.height,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'الطول (سم)'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: controller.weight,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'الوزن (كغ)'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: controller.birthYear,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سنة الميلاد'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الجنس', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Obx(() => Wrap(
                        spacing: 8,
                        children: [
                          for (final option in Sex.values)
                            GlassChip(
                              label: option.labelAr,
                              selected: controller.sex.value == option,
                              onTap: () => controller.sex.value = option,
                            ),
                        ],
                      )),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مستوى النشاط',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Obx(() => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in ActivityLevel.values)
                            GlassChip(
                              label: option.labelAr,
                              selected: controller.activity.value == option,
                              onTap: () => controller.activity.value = option,
                            ),
                        ],
                      )),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الهدف', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Obx(() => Wrap(
                        spacing: 8,
                        children: [
                          for (final option in Goal.values)
                            GlassChip(
                              label: option.labelAr,
                              selected: controller.goal.value == option,
                              onTap: () => controller.goal.value = option,
                            ),
                        ],
                      )),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _RateCard(controller: controller),
            const SizedBox(height: AppSpacing.md),
            Obx(() {
              final profile = controller.previewProfile;
              return profile == null
                  ? const SizedBox.shrink()
                  : EnergyBreakdownCard(profile: profile);
            }),
            const SizedBox(height: AppSpacing.md),
            _TargetPreview(controller: controller),
            const SizedBox(height: AppSpacing.md),
            Obx(() => GlassButton(
                  label: controller.saving.value
                      ? '...جارٍ الحفظ'
                      : 'حفظ التغييرات',
                  onPressed: controller.saving.value ? null : _save,
                )),
            const SizedBox(height: AppSpacing.xxl),
            Center(
              child: TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_forever_outlined,
                    color: AppPalette.danger),
                label: const Text('حذف الحساب نهائياً',
                    style: TextStyle(color: AppPalette.danger)),
              ),
            ),
          ],
        ),
      );
}

/// How hard the cut (or bulk) is, set in the unit people actually think in
/// -- kcal off the daily target -- with the resulting weight change spelled
/// out in kilograms so the number means something.
///
/// The two are one value in two units: the slider writes
/// `controller.dailyDelta`, which is `weeklyRateKg` converted through
/// [kKcalPerKg]. Nothing here recomputes the target itself.
class _RateCard extends StatelessWidget {
  final ProfileController controller;
  const _RateCard({required this.controller});

  /// 1 kg/week is 1100 kcal/day, past which the energy floor would clamp
  /// almost everyone anyway. Divisible by the 50 kcal step.
  static const _maxDelta = 1100.0;

  @override
  Widget build(BuildContext context) => Obx(() {
        final goal = controller.goal.value;
        if (goal == Goal.maintain) {
          return const GlassCard(
            child: Text(
              'الهدف هو الحفاظ على الوزن، لا يوجد عجز أو فائض يومي',
              style: TextStyle(color: AppPalette.muted),
            ),
          );
        }

        final cutting = goal == Goal.cut;
        final delta = controller.dailyDelta.clamp(0.0, _maxDelta);
        // The rate the target actually delivers, not the one requested --
        // the energy floor can clamp an aggressive cut down.
        final effective = controller.effectiveWeeklyKg;
        final weekly = effective?.abs() ?? controller.weeklyRate.value;

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cutting ? 'العجز اليومي' : 'الفائض اليومي',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${delta.round()}',
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(width: 6),
                  const Text('سعرة/يوم',
                      style: TextStyle(color: AppPalette.muted)),
                ],
              ),
              Slider(
                value: delta,
                min: 0,
                max: _maxDelta,
                divisions: (_maxDelta / 50).round(),
                label: '${delta.round()} سعرة',
                activeColor: AppPalette.emerald,
                onChanged: (value) => controller.dailyDelta = value,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                cutting
                    ? 'ستفقد حوالي ${weekly.toStringAsFixed(2)} كغ أسبوعياً'
                    : 'ستزيد حوالي ${weekly.toStringAsFixed(2)} كغ أسبوعياً',
                style: const TextStyle(
                    color: AppPalette.emerald, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'أي ${(weekly * 30 / 7).toStringAsFixed(1)} كغ في الشهر  •  '
                '${(weekly * 365 / 7).toStringAsFixed(0)} كغ في السنة',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (controller.rateWasClamped) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'العجز المطلوب يخفض السعرات تحت الحد الآمن، '
                  'لذلك تم تقليله إلى ما هو معروض أعلاه',
                  style: const TextStyle(color: AppPalette.amber)
                      .copyWith(fontSize: 12),
                ),
              ],
            ],
          ),
        );
      });
}

/// The before/after banner -- the requirement that made this screen more
/// than a form: changing a stat here shows what it does to today's target
/// before the user commits to it.
class _TargetPreview extends StatelessWidget {
  final ProfileController controller;
  const _TargetPreview({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() {
        final preview = controller.previewTargets;
        final delta = controller.kcalDelta;
        if (preview == null) {
          return const GlassCard(
            child: Text('أدخل بيانات صحيحة لمعاينة الهدف الجديد',
                style: TextStyle(color: AppPalette.muted)),
          );
        }
        final increased = (delta ?? 0) > 0;
        return GlassCard(
          highlighted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الهدف الجديد',
                  style: TextStyle(color: AppPalette.muted)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${preview.kcal.round()}',
                      style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(width: 6),
                  const Text('سعرة', style: TextStyle(color: AppPalette.muted)),
                  if (delta != null && delta.abs() >= 1) ...[
                    const SizedBox(width: 10),
                    Text(
                      '${increased ? '+' : ''}${delta.round()}',
                      style: TextStyle(
                        color:
                            increased ? AppPalette.amber : AppPalette.emerald,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'بروتين ${preview.macros.protein.round()}غ  •  '
                'كارب ${preview.macros.carbs.round()}غ  •  '
                'دهون ${preview.macros.fat.round()}غ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      });
}

/// Requires typing the exact word "حذف" -- not just a tap-through confirm --
/// before the delete button itself becomes enabled.
class _DeleteAccountDialog extends StatefulWidget {
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _text = TextEditingController();
  static const _phrase = 'حذف';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('حذف الحساب نهائياً؟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سيُحذف حسابك وكل بياناتك ولا يمكن التراجع. '
                'اكتب "$_phrase" للتأكيد.'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _text,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: _phrase),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: _text.text.trim() == _phrase
                ? () => Navigator.of(context).pop(true)
                : null,
            child:
                const Text('حذف', style: TextStyle(color: AppPalette.danger)),
          ),
        ],
      );
}
