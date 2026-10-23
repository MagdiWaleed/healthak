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

  /// Incrementing token from a tab arrival. A change replays the two-stage
  /// fill from zero. A plain [value] change (an eat-toggle) is NOT this -- the
  /// bar just glides to its new length in place.
  final int arrivalTrigger;
  final Duration stagger;
  final bool showHeader;

  const MacroBar(
      {required this.label,
      required this.value,
      required this.target,
      required this.color,
      this.planned,
      this.arrivalTrigger = 0,
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
            arrivalTrigger: arrivalTrigger,
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
  final int arrivalTrigger;
  final Duration stagger;

  const _MacroFill({
    required this.value,
    required this.planned,
    required this.target,
    required this.color,
    required this.arrivalTrigger,
    required this.stagger,
  });

  @override
  State<_MacroFill> createState() => _MacroFillState();
}

class _MacroFillState extends State<_MacroFill>
    with SingleTickerProviderStateMixin {
  static const _base = Duration(milliseconds: 820);

  /// The from-zero arrival envelope. Sits at 1 (settled) except while a tab
  /// arrival is replaying.
  late final AnimationController _sweep = AnimationController(
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
    // Only a tab arrival replays the sweep. A value change (eat-toggle) is
    // left to the implicit tweens below, so the page does not re-animate
    // under the user.
    if (old.arrivalTrigger != widget.arrivalTrigger) _play();
  }

  void _play() {
    if (MotionSettings.enabled(context)) {
      _sweep.forward(from: 0);
    } else {
      _sweep.value = 1;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  double get _eatenTarget => widget.target <= 0
      ? 0
      : (widget.value / widget.target).clamp(0.0, 1.0);

  double get _plannedTarget => widget.planned == null || widget.target <= 0
      ? 0
      : (widget.planned! / widget.target).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final total = _base + widget.stagger;
    final delay = total.inMilliseconds == 0
        ? 0.0
        : widget.stagger.inMilliseconds / total.inMilliseconds;
    const glide = Duration(milliseconds: 360);

    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        // Linear ramp after the stagger delay; each stage eases its own tail
        // so the bar reads as "linear, slowing only at the end".
        final raw = delay >= 1
            ? _sweep.value
            : ((_sweep.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final plannedStage =
            Curves.easeOut.transform((raw / 0.60).clamp(0.0, 1.0));
        final eatenStage =
            Curves.easeOut.transform(((raw - 0.32) / 0.68).clamp(0.0, 1.0));

        return TweenAnimationBuilder<double>(
          tween: Tween(end: _eatenTarget),
          duration: glide,
          curve: Curves.easeOut,
          builder: (context, eaten, __) {
            return TweenAnimationBuilder<double>(
              tween: Tween(end: _plannedTarget),
              duration: glide,
              curve: Curves.easeOut,
              builder: (context, plannedProgress, ___) {
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
                            widthFactor: plannedProgress * plannedStage,
                            child: ColoredBox(
                                color: widget.color.withValues(alpha: .38)),
                          ),
                        FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: eaten * eatenStage,
                          child: ColoredBox(color: widget.color),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
