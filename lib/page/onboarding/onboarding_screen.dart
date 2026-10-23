import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/nutrition/energy.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/components/energy_breakdown_card.dart';
import '../../ui/components/glass_field.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/motion_settings.dart';
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
                const SizedBox(height: 14),
                _OnboardingArc(
                  progress: controller.collectingProfile.value ? .66 : .33,
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

/// The first appearance of the ring vocabulary. Authentication and profile
/// completion are the two durable stages in the current onboarding flow, so
/// this fills between them without inventing a third persisted state.
class _OnboardingArc extends StatelessWidget {
  final double progress;
  const _OnboardingArc({required this.progress});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: MotionSettings.duration(
          context,
          const Duration(milliseconds: 420),
        ),
        curve: Curves.easeOutCubic,
        builder: (_, value, __) => Center(
          child: RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(58),
              painter: _OnboardingArcPainter(value),
              child: const Center(
                child: Icon(Icons.auto_graph_rounded,
                    size: 20, color: AppPalette.mint),
              ),
            ),
          ),
        ),
      );
}

class _OnboardingArcPainter extends CustomPainter {
  final double progress;
  const _OnboardingArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const start = -math.pi / 2;
    final stroke = size.width * .075;
    final arc = (Offset.zero & size).deflate(stroke);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: .12),
    );
    canvas.drawArc(
      arc,
      start,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = const SweepGradient(
          colors: [AppPalette.emerald, AppPalette.mint, AppPalette.emerald],
        ).createShader(arc),
    );
  }

  @override
  bool shouldRepaint(covariant _OnboardingArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
          final year = int.tryParse(controller.birthYear.text);
          final height = double.tryParse(controller.height.text);
          final weight = double.tryParse(controller.weight.text);
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: targets == null
                ? const SizedBox.shrink()
                : EnergyBreakdownCard.preview(
                    key: ValueKey(targets.kcal.round()),
                    weightKg: weight!,
                    heightCm: height!,
                    ageYears: DateTime.now().year - year!,
                    sex: controller.sex.value,
                    activity: controller.activity.value,
                    goal: controller.goal.value,
                    weeklyRateKg: controller.weeklyRate.value,
                    targets: targets,
                  ),
          );
        }),
        const SizedBox(height: 18),
        GlassButton(
            label: controller.busy.value ? '...' : AppStrings.saveProfile,
            onPressed: controller.busy.value ? null : controller.saveProfile),
      ]);
}
