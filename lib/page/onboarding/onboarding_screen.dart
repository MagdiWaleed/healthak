import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/nutrition/energy.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/components/glass_field.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends GetView<OnboardingController> {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => GlassScaffold(
        body: Obx(() => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                Text(
                  controller.collectingProfile.value
                      ? 'أخبرنا عن هدفك'
                      : AppStrings.guestHeadline,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                GlassCard(
                  child: controller.collectingProfile.value
                      ? _ProfileForm(controller)
                      : _AuthForm(controller),
                ),
                if (controller.error.value != null) ...[
                  const SizedBox(height: 12),
                  Text(controller.error.value!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            )),
      );
}

class _AuthForm extends StatelessWidget {
  final OnboardingController controller;
  const _AuthForm(this.controller);

  @override
  Widget build(BuildContext context) => Column(children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text(AppStrings.signIn)),
            ButtonSegment(value: false, label: Text(AppStrings.createAccount)),
          ],
          selected: {controller.isLogin.value},
          onSelectionChanged: (value) =>
              controller.isLogin.value = value.single,
        ),
        const SizedBox(height: 18),
        if (!controller.isLogin.value) ...[
          GlassField(
              controller: controller.name, label: AppStrings.displayName),
          const SizedBox(height: 12),
        ],
        GlassField(
            controller: controller.email,
            label: AppStrings.email,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        GlassField(
            controller: controller.password,
            label: AppStrings.password,
            obscureText: true),
        const SizedBox(height: 18),
        GlassButton(
          label: controller.busy.value
              ? '...'
              : controller.isLogin.value
                  ? AppStrings.signIn
                  : AppStrings.createAccount,
          onPressed: controller.busy.value ? null : controller.submitAuth,
        ),
        if (controller.isLogin.value)
          TextButton(
              onPressed: controller.resetPassword,
              child: const Text(AppStrings.resetPassword)),
      ]);
}

class _ProfileForm extends StatelessWidget {
  final OnboardingController controller;
  const _ProfileForm(this.controller);

  @override
  Widget build(BuildContext context) => Column(children: [
        GlassField(controller: controller.name, label: AppStrings.displayName),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: GlassField(
                  controller: controller.birthYear,
                  label: AppStrings.birthYear,
                  keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(
              child: GlassField(
                  controller: controller.height,
                  label: AppStrings.height,
                  keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 12),
        GlassField(
            controller: controller.weight,
            label: AppStrings.weight,
            keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        DropdownButtonFormField<Sex>(
          initialValue: controller.sex.value,
          items: Sex.values
              .map((value) =>
                  DropdownMenuItem(value: value, child: Text(value.labelAr)))
              .toList(),
          onChanged: (value) {
            controller.sex.value = value!;
            controller.recalculatePreview();
          },
          decoration: const InputDecoration(labelText: 'الجنس للحساب الغذائي'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ActivityLevel>(
          initialValue: controller.activity.value,
          items: ActivityLevel.values
              .map((value) =>
                  DropdownMenuItem(value: value, child: Text(value.labelAr)))
              .toList(),
          onChanged: (value) {
            controller.activity.value = value!;
            controller.recalculatePreview();
          },
          decoration: const InputDecoration(labelText: 'مستوى النشاط'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<Goal>(
          initialValue: controller.goal.value,
          items: Goal.values
              .map((value) =>
                  DropdownMenuItem(value: value, child: Text(value.labelAr)))
              .toList(),
          onChanged: (value) {
            controller.goal.value = value!;
            controller.recalculatePreview();
          },
          decoration: const InputDecoration(labelText: 'الهدف'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<double>(
          initialValue: controller.weeklyRate.value,
          items: const [.25, .5, .75, 1.0]
              .map((value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                        '${value.toStringAsFixed(value == 1 ? 0 : 2)} كجم'),
                  ))
              .toList(),
          onChanged: (value) {
            controller.weeklyRate.value = value!;
            controller.recalculatePreview();
          },
          decoration: const InputDecoration(labelText: 'المعدل الأسبوعي'),
        ),
        const SizedBox(height: 16),
        Obx(() {
          final targets = controller.previewTargets.value;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: targets == null
                ? const SizedBox.shrink()
                : Container(
                    key: ValueKey(targets.kcal.round()),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(children: [
                      const Text('هدفك اليومي المحسوب'),
                      Text(
                        '${targets.kcal.round()} سعرة',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'بروتين ${targets.macros.protein.round()} ج  •  '
                        'كربوهيدرات ${targets.macros.carbs.round()} ج  •  '
                        'دهون ${targets.macros.fat.round()} ج',
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
          );
        }),
        const SizedBox(height: 18),
        GlassButton(
            label: controller.busy.value ? '...' : AppStrings.saveProfile,
            onPressed: controller.busy.value ? null : controller.saveProfile),
      ]);
}
