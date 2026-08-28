import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'grain_texture.dart';

/// One drifting light source in the aurora field.
///
/// Each blob owns its own period. The periods are deliberately coprime-ish
/// so the composite pattern takes minutes to repeat -- a single shared
/// controller made all four move in lockstep, which reads as a pulse rather
/// than as drift. Kept short enough (7-13s) that the drift is visible within
/// the first few seconds of a freshly opened screen: a route pushed via
/// `Get.to()` starts its own `AuroraBackground` from t=0, and at the
/// originally-tuned 19-31s periods that first few seconds of a fresh instance
/// showed essentially no motion -- correct code, imperceptible result, which
/// read as "the background stopped moving" on every screen except the one
/// tab (Today) the app happens to have been sitting on long enough to
/// accumulate visible drift.
class _BlobSpec {
  final Alignment anchor;
  final Color color;

  /// Fraction of the shortest side. The blob radius breathes around this.
  final double radius;

  /// Travel amplitude as a fraction of width / height.
  final double ampX;
  final double ampY;

  /// Phase offset so no two blobs start at the same point on their path.
  final double phase;

  final Duration period;

  const _BlobSpec({
    required this.anchor,
    required this.color,
    required this.radius,
    required this.ampX,
    required this.ampY,
    required this.phase,
    required this.period,
  });
}

const _blobs = <_BlobSpec>[
  _BlobSpec(
    anchor: Alignment(-0.75, -0.85),
    color: AppPalette.emerald,
    radius: 0.95,
    ampX: 0.10,
    ampY: 0.07,
    phase: 0.0,
    period: Duration(seconds: 7),
  ),
  _BlobSpec(
    anchor: Alignment(0.85, -0.55),
    color: AppPalette.violet,
    radius: 0.88,
    ampX: 0.09,
    ampY: 0.10,
    phase: 1.7,
    period: Duration(seconds: 9),
  ),
  _BlobSpec(
    anchor: Alignment(-0.35, 0.55),
    color: AppPalette.amber,
    radius: 0.80,
    ampX: 0.12,
    ampY: 0.06,
    phase: 3.1,
    period: Duration(seconds: 11),
  ),
  _BlobSpec(
    anchor: Alignment(0.80, 0.95),
    color: AppPalette.mint,
    radius: 0.70,
    ampX: 0.07,
    ampY: 0.09,
    phase: 4.4,
    period: Duration(seconds: 13),
  ),
];

/// The app's ambient background: a near-black base, four slow radial-gradient
/// light sources, a vignette, and a fixed grain overlay.
///
/// The softness comes entirely from the gradients. There is no [ImageFilter]
/// here and there must never be one -- the whole glass budget is reserved for
/// the two [GlassSurface]s above this layer.
class AuroraBackground extends StatefulWidget {
  final Widget child;

  /// When false the field renders once, statically, and no controller ticks.
  final bool animate;
  final bool showGrain;

  /// Scales every blob period. `> 1` is slower. Used by the balanced quality
  /// tier to halve the tick rate's perceptual cost without stopping motion.
  final double speedScale;

  /// Optional Phase-2 color treatment. The geometry remains fixed so mood
  /// changes do not add painter work or a second animation layer.
  final List<Color>? blobColors;
  final double blobAlphaMultiplier;
  final double vignetteAlpha;
  final double grainOpacity;

  const AuroraBackground({
    required this.child,
    super.key,
    this.animate = true,
    this.showGrain = true,
    this.speedScale = 1.0,
    this.blobColors,
    this.blobAlphaMultiplier = 1.0,
    this.vignetteAlpha = .55,
    this.grainOpacity = .045,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late Listenable _merged;

  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create() {
    _controllers = [
      for (final blob in _blobs)
        AnimationController(
          vsync: this,
          duration: blob.period * widget.speedScale,
        ),
    ];
    _merged = Listenable.merge(_controllers);
    if (widget.animate) {
      for (final c in _controllers) {
        c.repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speedScale != widget.speedScale) {
      for (var i = 0; i < _controllers.length; i++) {
        _controllers[i].duration = _blobs[i].period * widget.speedScale;
      }
    }
    if (oldWidget.animate != widget.animate) {
      for (final c in _controllers) {
        if (widget.animate) {
          c.repeat(reverse: true);
        } else {
          c.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          // Its own layer. Without this boundary the aurora's 60fps repaint
          // drags every widget in `child` into the same dirty layer.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _merged,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(
                  t: [for (final c in _controllers) c.value],
                  colors: widget.blobColors,
                  alphaMultiplier: widget.blobAlphaMultiplier,
                  vignetteAlpha: widget.vignetteAlpha,
                ),
                isComplex: true,
                willChange: widget.animate,
                size: Size.infinite,
              ),
            ),
          ),
          if (widget.showGrain) GrainTexture(opacity: widget.grainOpacity),
          widget.child,
        ],
      );
}

class _AuroraPainter extends CustomPainter {
  /// One 0..1 ping-pong value per blob, in `_blobs` order.
  final List<double> t;
  final List<Color>? colors;
  final double alphaMultiplier;
  final double vignetteAlpha;

  const _AuroraPainter({
    required this.t,
    required this.colors,
    required this.alphaMultiplier,
    required this.vignetteAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shortest = size.shortestSide;

    canvas.drawRect(rect, Paint()..color = AppPalette.ink);

    for (var i = 0; i < _blobs.length; i++) {
      final blob = _blobs[i];
      final phase = t[i] * math.pi + blob.phase;

      // x traverses half a cycle while y traverses a full one, so the path is
      // a shallow figure-eight rather than the straight line a single shared
      // offset produced.
      final dx = math.cos(phase) * blob.ampX * size.width;
      final dy = math.sin(phase * 2) * blob.ampY * size.height;

      final center = Offset(
        rect.center.dx + blob.anchor.x * size.width / 2 + dx,
        rect.center.dy + blob.anchor.y * size.height / 2 + dy,
      );

      // Breathing. A static radius is what made the old field read as a
      // flat gradient someone slid around.
      final breathe = 1 + 0.14 * math.sin(phase * 1.5);
      final radius = shortest * blob.radius * breathe;
      final alpha = 0.34 + 0.10 * math.sin(phase + 1.0);

      _blobPaint(
        canvas,
        center,
        radius,
        colors?[i] ?? blob.color,
        alpha * alphaMultiplier,
      );
    }

    _vignette(canvas, rect, vignetteAlpha);
  }

  void _blobPaint(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          // A hard mid-stop keeps the core readable while the falloff stays
          // long. A plain two-stop gradient washes out into grey.
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(bounds),
    );
  }

  /// Darkens the corners so glass surfaces have something to sit against.
  void _vignette(Canvas canvas, Rect rect, double alpha) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            AppPalette.ink.withValues(alpha: 0),
            AppPalette.ink.withValues(alpha: alpha),
          ],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) {
    if (!listEquals(old.colors, colors) ||
        old.alphaMultiplier != alphaMultiplier ||
        old.vignetteAlpha != vignetteAlpha) {
      return true;
    }
    for (var i = 0; i < t.length; i++) {
      if (old.t[i] != t[i]) {
        return true;
      }
    }
    return false;
  }
}
