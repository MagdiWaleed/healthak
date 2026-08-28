import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/glass_tokens.dart';
import 'glass_decoration.dart';

/// One scroll-fed light angle shared by every glass surface in a screen.
class SpecularScope extends InheritedNotifier<ValueNotifier<double>> {
  const SpecularScope({
    required ValueNotifier<double> angle,
    required super.child,
    super.key,
  }) : super(notifier: angle);

  static ValueListenable<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpecularScope>()?.notifier;
}

/// A cheap, scroll-reactive glass edge. It uses gradients and a stroke only;
/// no filter is introduced in lists or elsewhere.
class SpecularBorder extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double intensity;

  const SpecularBorder({
    required this.child,
    required this.borderRadius,
    super.key,
    this.intensity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final angle = SpecularScope.maybeOf(context);
    if (angle == null) {
      return RepaintBoundary(
        child: CustomPaint(
          foregroundPainter: _SpecularBorderPainter(
            borderRadius: borderRadius,
            intensity: intensity,
          ),
          child: child,
        ),
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: angle,
      child: child,
      builder: (context, value, child) => RepaintBoundary(
        child: CustomPaint(
          foregroundPainter: _SpecularBorderPainter(
            borderRadius: borderRadius,
            intensity: intensity,
            angleDegrees: value,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SpecularBorderPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final double intensity;
  final double angleDegrees;

  const _SpecularBorderPainter({
    required this.borderRadius,
    required this.intensity,
    this.angleDegrees = -135,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(.5);
    final edge = intensity == 1
        ? GlassDecoration.edge
        : LinearGradient(
            begin: GlassDecoration.edge.begin,
            end: GlassDecoration.edge.end,
            stops: GlassDecoration.edge.stops,
            colors: [
              for (final color in GlassDecoration.edge.colors)
                color.withValues(alpha: color.a * intensity),
            ],
          );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = edge.createShader(rect),
    );

    const arcFraction = GlassTokens.specularSweepDeg / 360;
    final highlight = SweepGradient(
      transform: GradientRotation(angleDegrees * math.pi / 180),
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: .68 * intensity),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: const [0, arcFraction * .42, arcFraction, 1],
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..shader = highlight.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SpecularBorderPainter old) =>
      old.borderRadius != borderRadius ||
      old.intensity != intensity ||
      old.angleDegrees != angleDegrees;
}
