import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/motion_settings.dart';

/// A contained, ring-local goal moment. The trigger is an incrementing token
/// from TodayController; a new token restarts rather than stacks the effect.
class GoalCelebration extends StatefulWidget {
  final int trigger;
  final Widget child;
  const GoalCelebration({
    required this.trigger,
    required this.child,
    super.key,
  });

  @override
  State<GoalCelebration> createState() => _GoalCelebrationState();
}

class _GoalCelebrationState extends State<GoalCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didUpdateWidget(covariant GoalCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      if (MotionSettings.enabled(context)) {
        _controller.forward(from: 0);
      } else {
        final token = widget.trigger;
        _controller.value = 1;
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (mounted && widget.trigger == token) _controller.reset();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = MotionSettings.enabled(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (_, child) {
        final t =
            enabled ? _controller.value : (_controller.value > 0 ? 1.0 : 0.0);
        final pulse = _doublePulse(t);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: const Size.square(320),
                painter: _CelebrationPainter(progress: t),
              ),
            ),
            Transform.scale(scale: pulse, child: child),
            if (t > .38)
              Positioned(
                bottom: -22,
                child: Opacity(
                  opacity: ((t - .38) / .18).clamp(0.0, 1.0) *
                      (1 - ((t - .82) / .18).clamp(0.0, 1.0)),
                  child: Text(
                    AppStrings.goalReached[
                        widget.trigger % AppStrings.goalReached.length],
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppPalette.mint,
                          fontFeatures: AppTypography.tabular,
                        ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _doublePulse(double t) {
    if (t >= .6) return 1;
    final first = math.sin((t / .36).clamp(0.0, 1.0) * math.pi) * .03;
    final second = math.sin(((t - .22) / .38).clamp(0.0, 1.0) * math.pi) * .02;
    return 1 + first + second;
  }
}

class _CelebrationPainter extends CustomPainter {
  final double progress;
  const _CelebrationPainter({required this.progress});

  static final _random = math.Random(7707);
  static final _particles = List.generate(
      24,
      (i) => (
            angle: -math.pi / 2 + (_random.nextDouble() - .5) * 2.3,
            distance: 72 + _random.nextDouble() * 92,
            size: 2.3 + _random.nextDouble() * 2.5,
          ));
  static const _colors = [
    AppPalette.emerald,
    AppPalette.mint,
    AppPalette.amber,
    AppPalette.violet
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final centre = size.center(Offset.zero);
    final glowProgress =
        Curves.easeOut.transform((progress / .82).clamp(0.0, 1.0));
    canvas.drawCircle(
      centre,
      105 + 62 * glowProgress,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppPalette.mint.withValues(alpha: .28 * (1 - progress * .35)),
            Colors.transparent
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: 170)),
    );
    final flight = ((progress - .05) / .72).clamp(0.0, 1.0);
    final alpha = (1 - ((progress - .68) / .32).clamp(0.0, 1.0)) * .92;
    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final point = Offset(
        centre.dx + math.cos(p.angle) * p.distance * flight,
        centre.dy +
            math.sin(p.angle) * p.distance * flight +
            55 * flight * flight,
      );
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: alpha);
      if (i % 5 == 0) {
        canvas.save();
        canvas.translate(point.dx, point.dy);
        canvas.rotate(progress * math.pi * 2);
        final path = Path()
          ..moveTo(0, -p.size * 1.8)
          ..lineTo(p.size * .55, -p.size * .55)
          ..lineTo(p.size * 1.8, 0)
          ..lineTo(p.size * .55, p.size * .55)
          ..lineTo(0, p.size * 1.8)
          ..lineTo(-p.size * .55, p.size * .55)
          ..lineTo(-p.size * 1.8, 0)
          ..lineTo(-p.size * .55, -p.size * .55)
          ..close();
        canvas.drawPath(path, paint);
        canvas.restore();
      } else {
        canvas.drawCircle(point, p.size, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
