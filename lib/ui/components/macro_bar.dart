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

  /// An incrementing token from a parent action. A change replays the fill
  /// from zero; each macro can add a small delay so the three bars settle as
  /// a sequence rather than together.
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

class _MacroFill extends StatefulWidget {
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
  State<_MacroFill> createState() => _MacroFillState();
}

class _MacroFillState extends State<_MacroFill>
    with SingleTickerProviderStateMixin {
  static const _base = Duration(milliseconds: 820);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _base + widget.stagger,
    value: 1,
  );
  bool _primed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_primed) return;
    _primed = true;
    _play();
  }

  @override
  void didUpdateWidget(covariant _MacroFill old) {
    super.didUpdateWidget(old);
    if (old.animationTrigger != widget.animationTrigger) _play();
  }

  void _play() {
    if (MotionSettings.enabled(context)) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _base + widget.stagger;
    final delay = total.inMilliseconds == 0
        ? 0.0
        : widget.stagger.inMilliseconds / total.inMilliseconds;
    final eaten =
        widget.target <= 0 ? 0.0 : (widget.value / widget.target).clamp(0.0, 1.0);
    final plannedProgress = widget.planned == null || widget.target <= 0
        ? 0.0
        : (widget.planned! / widget.target).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Linear ramp after the stagger delay; the two stages ease their own
        // tails so the bar reads as "linear, slowing only at the end".
        final raw = delay >= 1
            ? _controller.value
            : ((_controller.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final plannedT =
            Curves.easeOut.transform((raw / 0.60).clamp(0.0, 1.0));
        final eatenT =
            Curves.easeOut.transform(((raw - 0.32) / 0.68).clamp(0.0, 1.0));

        return ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: widget.color.withValues(alpha: .13)),
                if (plannedProgress > eaten)
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: plannedProgress * plannedT,
                    child:
                        ColoredBox(color: widget.color.withValues(alpha: .38)),
                  ),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: eaten * eatenT,
                  child: ColoredBox(color: widget.color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
