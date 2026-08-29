import 'package:flutter/material.dart';

import '../theme/motion_settings.dart';

class MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  /// Optional planned total. When it extends past [value], the extra portion
  /// sits behind the eaten amount as a quiet, translucent preview.
  final double? planned;

  /// An incrementing token from a parent action. Each macro can add a small
  /// delay so the three bars settle as a sequence rather than together.
  final int animationTrigger;
  final Duration stagger;
  final bool showHeader;

  const MacroBar(
      {required this.label,
      required this.value,
      required this.target,
      required this.color,
      this.planned,
      this.animationTrigger = 0,
      this.stagger = Duration.zero,
      this.showHeader = true,
      super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(children: [
              Expanded(child: Text(label)),
              Text('${value.round()} / ${target.round()} غ')
            ]),
            const SizedBox(height: 6),
          ],
          _MacroFill(
            value: value,
            planned: planned,
            target: target,
            color: color,
            animationTrigger: animationTrigger,
            stagger: stagger,
          ),
        ],
      );
}

class _MacroFill extends StatelessWidget {
  final double value;
  final double? planned;
  final double target;
  final Color color;
  final int animationTrigger;
  final Duration stagger;

  const _MacroFill({
    required this.value,
    required this.planned,
    required this.target,
    required this.color,
    required this.animationTrigger,
    required this.stagger,
  });

  @override
  Widget build(BuildContext context) {
    final total = const Duration(milliseconds: 360) + stagger;
    final delay = stagger.inMilliseconds / total.inMilliseconds;
    final curve = Interval(delay, 1, curve: Curves.easeOutCubic);
    final eaten = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final plannedProgress = planned == null || target <= 0
        ? 0.0
        : (planned! / target).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      key: ValueKey(animationTrigger),
      tween: Tween(end: 1.0),
      duration: MotionSettings.duration(context, total),
      curve: curve,
      builder: (_, progress, __) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: color.withValues(alpha: .13)),
              if (plannedProgress > eaten)
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: plannedProgress * progress,
                  child: ColoredBox(color: color.withValues(alpha: .38)),
                ),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: eaten * progress,
                child: ColoredBox(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
