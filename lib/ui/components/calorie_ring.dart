import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/nutrition/macros.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../motion/eat_toggle/ring_ripple.dart';

/// The day's headline figure: a sweeping calorie arc with three macro rings
/// nested inside it.
///
/// The number counts up in step with the arc -- both read from the same tween,
/// so the figure can never show a total the ring has not reached yet.
///
/// [plannedKcal]/[plannedMacros] add a second, faded segment past the solid
/// consumed arc, running out to wherever today's *planned* total (eaten or
/// not -- everything scheduled or logged) would land. This answers "if I eat
/// everything already on today's plan, do I still need to add or remove
/// something?" without waiting until it's actually eaten to find out. Passing
/// neither leaves the ring exactly as it was: solid arc only.
class CalorieRing extends StatelessWidget {
  final double consumed;
  final double target;
  final double size;
  final Macros consumedMacros;
  final Macros targetMacros;

  final double? plannedKcal;
  final Macros? plannedMacros;
  final Color ringAccent;
  final int rippleTrigger;

  /// Set false for a ring rebuilt on every eat-toggle, where a sweep from zero
  /// would fight the user.
  final bool animateFromZero;

  const CalorieRing({
    required this.consumed,
    required this.target,
    super.key,
    this.size = 200,
    this.consumedMacros = Macros.zero,
    this.targetMacros = Macros.zero,
    this.plannedKcal,
    this.plannedMacros,
    this.ringAccent = AppPalette.emerald,
    this.rippleTrigger = 0,
    this.animateFromZero = true,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final planned = plannedKcal;

    return TweenAnimationBuilder<double>(
      // Animating kcal rather than the 0..1 ratio keeps the counter and the
      // arc reading from one source.
      tween: Tween(begin: animateFromZero ? 0 : consumed, end: consumed),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, kcal, _) {
        final progress = target <= 0 ? 0.0 : kcal / target;
        final plannedProgress =
            (planned != null && target > 0) ? planned / target : null;
        final over = progress > 1;
        final remaining = (target - kcal).round();

        return RingRipple(
          trigger: rippleTrigger,
          color: ringAccent,
          child: SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                plannedProgress: plannedProgress,
                consumedMacros: consumedMacros,
                targetMacros: targetMacros,
                plannedMacros: plannedMacros,
                ringAccent: ringAccent,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kcal.round().toString(),
                      style: text.displayLarge?.copyWith(
                        fontSize: size * .19,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -1,
                        fontFeatures: AppTypography.tabular,
                        color: over ? AppPalette.amber : AppPalette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      over
                          ? '${AppRingLabels.over} ${-remaining}'
                          : '$remaining ${AppRingLabels.remaining}',
                      style: text.bodyMedium?.copyWith(
                        color: over ? AppPalette.amber : AppPalette.muted,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                    if (plannedProgress != null &&
                        plannedProgress > progress + 0.005) ...[
                      const SizedBox(height: 1),
                      Text(
                        '${AppRingLabels.plannedTo} ${planned!.round()}',
                        style:
                            text.labelSmall?.copyWith(color: AppPalette.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kept beside the widget rather than in `AppStrings` because both labels are
/// specific to the ring's two states and are never reused.
abstract final class AppRingLabels {
  static const remaining = 'سعرة متبقية';
  static const over = 'تجاوزت بـ';
  static const plannedTo = 'مخطط حتى';
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double? plannedProgress;
  final Macros consumedMacros;
  final Macros targetMacros;
  final Macros? plannedMacros;
  final Color ringAccent;

  const _RingPainter({
    required this.progress,
    required this.consumedMacros,
    required this.targetMacros,
    this.plannedProgress,
    this.plannedMacros,
    required this.ringAccent,
  });

  /// Twelve o'clock. Every arc and the sweep gradient are anchored here.
  static const _start = -math.pi / 2;

  static const _macroColors = [
    AppPalette.emerald,
    AppPalette.amber,
    AppPalette.violet,
  ];

  /// The rotation is load-bearing: a SweepGradient starts at 3 o'clock while
  /// the arc starts at 12, so without it the sweep began mid-palette instead
  /// of on emerald.
  SweepGradient get _sweep => SweepGradient(
        colors: [
          ringAccent,
          AppPalette.mint,
          AppPalette.amber,
          AppPalette.violet,
          ringAccent,
        ],
        stops: const [0.0, 0.28, 0.58, 0.82, 1.0],
        transform: const GradientRotation(_start),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * .075;
    final arc = rect.deflate(stroke / 2 + size.width * .02);

    _track(canvas, arc, stroke);

    final swept = progress.clamp(0.0, 1.0) * math.pi * 2;

    // The planned-but-not-yet-eaten band sits UNDER the solid consumed arc,
    // so it never gets painted over -- it's what shows between "where you
    // are" and "where today's plan would take you."
    final planned = plannedProgress;
    if (planned != null && planned > progress) {
      final plannedSwept = planned.clamp(0.0, 1.0) * math.pi * 2;
      _plannedArc(canvas, arc, stroke, swept, plannedSwept);
    }

    if (swept > 0) {
      _progressArc(canvas, rect, arc, stroke, swept);
      _head(canvas, arc, stroke, swept);
    }

    // Past target the overage rides on top of the completed ring in a warning
    // hue, so "how far over" stays legible instead of the arc just stopping.
    if (progress > 1) {
      final overSwept = (progress - 1).clamp(0.0, 1.0) * math.pi * 2;
      canvas.drawArc(
        arc,
        _start,
        overSwept,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke * .55
          ..color = AppPalette.amber.withValues(alpha: .85),
      );
    }

    _macroRings(canvas, rect, stroke);
  }

  void _track(Canvas canvas, Rect arc, double stroke) {
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: .08),
    );
  }

  /// A neutral (not gradient-colored) faded band from the current position
  /// out to the planned one. Deliberately not the vivid sweep gradient --
  /// this is a preview, not progress, and using the same vivid treatment
  /// would read as "already eaten."
  void _plannedArc(
    Canvas canvas,
    Rect arc,
    double stroke,
    double fromSwept,
    double toSwept,
  ) {
    canvas.drawArc(
      arc,
      _start + fromSwept,
      toSwept - fromSwept,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: .22),
    );
  }

  void _progressArc(
    Canvas canvas,
    Rect rect,
    Rect arc,
    double stroke,
    double swept,
  ) {
    final shader = _sweep.createShader(rect);

    // Bloom, built from two wider low-alpha passes. A MaskFilter.blur would
    // look similar and cost a real blur on every frame of the sweep.
    for (final pass in const [(2.6, .10), (1.7, .16)]) {
      canvas.drawArc(
        arc,
        _start,
        swept,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke * pass.$1
          ..shader = shader
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: pass.$2),
      );
    }

    canvas.drawArc(
      arc,
      _start,
      swept,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = shader,
    );
  }

  /// A bright dot riding the tip of the arc. Small detail, but it is what
  /// makes the ring read as *moving* rather than as a static wedge.
  void _head(Canvas canvas, Rect arc, double stroke, double swept) {
    final angle = _start + swept;
    final centre = arc.center;
    final radius = arc.width / 2;
    final tip = Offset(
      centre.dx + math.cos(angle) * radius,
      centre.dy + math.sin(angle) * radius,
    );

    canvas.drawCircle(
      tip,
      stroke * .78,
      Paint()..color = Colors.white.withValues(alpha: .18),
    );
    canvas.drawCircle(
      tip,
      stroke * .30,
      Paint()..color = Colors.white.withValues(alpha: .92),
    );
  }

  void _macroRings(Canvas canvas, Rect rect, double stroke) {
    final consumedRatios = [
      _ratio(consumedMacros.protein, targetMacros.protein),
      _ratio(consumedMacros.carbs, targetMacros.carbs),
      _ratio(consumedMacros.fat, targetMacros.fat),
    ];
    final planned = plannedMacros;
    final plannedRatios = planned == null
        ? null
        : [
            _ratio(planned.protein, targetMacros.protein),
            _ratio(planned.carbs, targetMacros.carbs),
            _ratio(planned.fat, targetMacros.fat),
          ];
    final width = math.max(2.5, stroke * .22);

    for (var i = 0; i < consumedRatios.length; i++) {
      final ring = rect.deflate(stroke * (1.9 + i * .62));
      final color = _macroColors[i];

      // A track behind each one, so a macro at zero is still visible as an
      // empty ring rather than as nothing at all.
      canvas.drawArc(
        ring,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: .13),
      );

      // Same layering as the main ring: the faded planned band sits under
      // the solid consumed arc.
      final plannedRatio = plannedRatios?[i];
      if (plannedRatio != null && plannedRatio > consumedRatios[i]) {
        canvas.drawArc(
          ring,
          _start + math.pi * 2 * consumedRatios[i],
          math.pi * 2 * (plannedRatio - consumedRatios[i]),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt
            ..strokeWidth = width
            ..color = color.withValues(alpha: .38),
        );
      }

      if (consumedRatios[i] <= 0) continue;
      canvas.drawArc(
        ring,
        _start,
        math.pi * 2 * consumedRatios[i],
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width
          ..color = color,
      );
    }
  }

  double _ratio(double value, double target) =>
      target <= 0 ? 0 : (value / target).clamp(0.0, 1.0);

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.plannedProgress != plannedProgress ||
      old.consumedMacros != consumedMacros ||
      old.targetMacros != targetMacros ||
      old.plannedMacros != plannedMacros ||
      old.ringAccent != ringAccent;
}
