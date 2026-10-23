import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';
import 'grain_texture.dart';

/// One drifting light source in the aurora field.
///
/// Each blob owns its own period. The periods are deliberately coprime-ish
/// so the composite pattern takes minutes to repeat -- a single shared
/// controller made all four move in lockstep, which reads as a pulse rather
/// than as drift.
///
/// Periods are on the slow side (11-20s) for a calm, "breathing room" drift.
/// A previous pass at 19-31s read as motionless in the first seconds of a
/// freshly pushed route; the amplitudes here are a touch wider than that
/// attempt so the drift stays legible without speeding the field back up.
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
    ampX: 0.115,
    ampY: 0.08,
    phase: 0.0,
    period: Duration(seconds: 11),
  ),
  _BlobSpec(
    anchor: Alignment(0.85, -0.55),
    color: AppPalette.violet,
    radius: 0.88,
    ampX: 0.105,
    ampY: 0.115,
    phase: 1.7,
    period: Duration(seconds: 14),
  ),
  _BlobSpec(
    anchor: Alignment(-0.35, 0.55),
    color: AppPalette.amber,
    radius: 0.80,
    ampX: 0.14,
    ampY: 0.07,
    phase: 3.1,
    period: Duration(seconds: 17),
  ),
  _BlobSpec(
    anchor: Alignment(0.80, 0.95),
    color: AppPalette.mint,
    radius: 0.70,
    ampX: 0.08,
    ampY: 0.105,
    phase: 4.4,
    period: Duration(seconds: 20),
  ),
];

/// The app's ambient background: a near-black base, four slow radial-gradient
/// light sources, a vignette, and a fixed grain overlay.
///
/// The softness comes entirely from the gradients. There is no [ImageFilter]
/// here and there must never be one -- the whole glass budget is reserved for
/// the two [GlassSurface]s above this layer.
///
/// The field is driven by a single [Ticker] that only rebuilds the painter
/// at [maxFps] rather than every vsync. The blobs move well under a pixel per
/// frame, so a 30fps drift is visually identical to 60 while removing a
/// full-screen multi-gradient raster from every other frame -- this is the
/// single largest steady-state GPU cost in the app.
class AuroraBackground extends StatefulWidget {
  final Widget child;

  /// When false the field renders once, statically, and no ticker runs.
  final bool animate;
  final bool showGrain;

  /// Scales every blob period. `> 1` is slower. Used by the balanced quality
  /// tier alongside a lower [maxFps].
  final double speedScale;

  /// Painter rebuilds per second while animating. 30 for the high tier, lower
  /// for balanced. Does not change how fast the drift *looks*, only how often
  /// it is re-rasterized.
  final double maxFps;

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
    this.maxFps = 30,
    this.blobColors,
    this.blobAlphaMultiplier = 1.0,
    this.vignetteAlpha = .55,
    this.grainOpacity = .045,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;

  /// Bumped on each throttled frame to drive the painter rebuild. A plain
  /// counter rather than a time value so identical repeats still repaint.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  Duration _elapsed = Duration.zero;
  Duration _lastEmit = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _startTicker();
  }

  void _startTicker() {
    final ticker = _ticker ??= createTicker(_onTick);
    if (!ticker.isActive) ticker.start();
  }

  Duration get _minInterval =>
      Duration(microseconds: (1000000 / widget.maxFps).round());

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    if (elapsed - _lastEmit >= _minInterval) {
      _lastEmit = elapsed;
      _frame.value++;
    }
  }

  @override
  void didUpdateWidget(covariant AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _startTicker();
      } else {
        _ticker?.stop();
      }
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// 0..1..0 ping-pong for one blob, matching the shape the old
  /// `AnimationController.repeat(reverse: true)` produced but computed from
  /// the single shared clock.
  double _blobT(_BlobSpec blob) {
    final halfPeriodUs = blob.period.inMicroseconds * widget.speedScale;
    if (halfPeriodUs <= 0) return 0;
    final cycle = (_elapsed.inMicroseconds / halfPeriodUs) % 2.0;
    return cycle <= 1.0 ? cycle : 2.0 - cycle;
  }

  Widget _field() => CustomPaint(
        painter: _AuroraPainter(
          t: [for (final blob in _blobs) _blobT(blob)],
          colors: widget.blobColors,
          alphaMultiplier: widget.blobAlphaMultiplier,
          vignetteAlpha: widget.vignetteAlpha,
        ),
        isComplex: true,
        willChange: widget.animate,
        size: Size.infinite,
      );

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          // Its own layer. Without this boundary the aurora's repaint drags
          // every widget in `child` into the same dirty layer.
          RepaintBoundary(
            child: widget.animate
                ? ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (context, _, __) => _field(),
                  )
                : _field(),
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
