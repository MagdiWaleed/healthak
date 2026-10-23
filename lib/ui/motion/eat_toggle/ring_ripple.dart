import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/motion_settings.dart';

/// Expanding light from the calorie ring after a positive eat action.
class RingRipple extends StatefulWidget {
  final int trigger;
  final Widget child;
  final Color color;
  const RingRipple({
    required this.trigger,
    required this.child,
    this.color = AppPalette.emerald,
    super.key,
  });

  @override
  State<RingRipple> createState() => _RingRippleState();
}

class _RingRippleState extends State<RingRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(covariant RingRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.square(220 + 40 * _controller.value),
                painter: _RipplePainter(
                  progress:
                      MotionSettings.enabled(context) ? _controller.value : 1,
                  color: widget.color,
                ),
              ),
            ),
            child!,
          ],
        ),
      );
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final radius = size.shortestSide * (.39 + .09 * progress);
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: .5 * (1 - progress)),
    );
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
