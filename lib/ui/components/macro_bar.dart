import 'package:flutter/material.dart';

class MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  /// An incrementing token from a parent action. Each macro can add a small
  /// delay so the three bars settle as a sequence rather than together.
  final int animationTrigger;
  final Duration stagger;

  const MacroBar(
      {required this.label,
      required this.value,
      required this.target,
      required this.color,
      this.animationTrigger = 0,
      this.stagger = Duration.zero,
      super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label)),
            Text('${value.round()} / ${target.round()} غ')
          ]),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            key: ValueKey(animationTrigger),
            tween: Tween(end: target <= 0 ? 0 : (value / target).clamp(0, 1)),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            builder: (_, progress, __) => LinearProgressIndicator(
              value: progress,
              color: color,
            ),
          ),
        ],
      );
}
