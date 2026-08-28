import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';

/// Shared surface treatment for every glass widget.
///
/// The light source is fixed at the top-left and is deliberately **not**
/// direction-aware. Glass catches light from a physical direction; flipping the
/// highlight with the text direction would make the whole surface look like it
/// changes material between locales.
abstract final class GlassDecoration {
  /// Body tint. Brighter at the top so the surface has a vertical gradient
  /// even before the specular lands on it.
  static LinearGradient body({
    double top = .16,
    double bottom = .055,
  }) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: top),
          Colors.white.withValues(alpha: bottom),
        ],
      );

  /// The sheen across the upper portion of the surface.
  ///
  /// This is the single detail that separates "glass" from "translucent grey
  /// box". It was specified in the design system and never implemented.
  static const specular = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x2EFFFFFF),
      Color(0x0AFFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.35, 0.62],
  );

  /// Edge light: bright where the source hits, dim through the middle, with a
  /// weaker bounce on the far edge. A uniform `Border.all` reads as a drawn
  /// outline rather than as a lit edge.
  static const edge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x73FFFFFF),
      Color(0x1AFFFFFF),
      Color(0x0DFFFFFF),
      Color(0x3DFFFFFF),
    ],
    stops: [0.0, 0.32, 0.68, 1.0],
  );

  static List<BoxShadow> shadowsFor(GlassElevation level) => switch (level) {
        GlassElevation.flush => const [],
        GlassElevation.card => const [
            BoxShadow(
                color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        GlassElevation.panel => const [
            BoxShadow(
                color: Color(0x4D000000), blurRadius: 18, offset: Offset(0, 8)),
          ],
        GlassElevation.hero => [
            const BoxShadow(
                color: Color(0x59000000),
                blurRadius: 32,
                offset: Offset(0, 14)),
            BoxShadow(
              color: AppPalette.emerald.withValues(alpha: .18),
              blurRadius: 24,
              spreadRadius: -2,
            ),
          ],
      };
}

/// Strokes the surface outline with [GlassDecoration.edge].
///
/// A foreground painter rather than a `Border`, because `Border` cannot take a
/// shader and a uniform-colour edge is what makes glass look flat.
class GlassEdgePainter extends CustomPainter {
  final BorderRadius borderRadius;
  final double width;
  final double intensity;

  const GlassEdgePainter({
    required this.borderRadius,
    this.width = 1.0,
    this.intensity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Inset by half the stroke so the line sits inside the clip instead of
    // being shaved in half by it.
    final rrect = borderRadius.toRRect(rect).deflate(width / 2);

    // Intensity has to be folded into the gradient stops: Skia ignores
    // Paint.color entirely once a shader is attached.
    final gradient = intensity == 1.0
        ? GlassDecoration.edge
        : LinearGradient(
            begin: GlassDecoration.edge.begin,
            end: GlassDecoration.edge.end,
            stops: GlassDecoration.edge.stops,
            colors: [
              for (final c in GlassDecoration.edge.colors)
                c.withValues(alpha: c.a * intensity),
            ],
          );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant GlassEdgePainter old) =>
      old.borderRadius != borderRadius ||
      old.width != width ||
      old.intensity != intensity;
}
