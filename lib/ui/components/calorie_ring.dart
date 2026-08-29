import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/nutrition/macros.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/motion_settings.dart';
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
///
/// On tab arrival ([arrivalTrigger] changing) the ring plays a two-stage fill:
/// the faded planned band sweeps out first, then the solid consumed arc and
/// the counter follow over it -- both on a near-linear curve that eases only
/// at the very end. An eat-toggle does not replay this; the value simply
/// tweens to its new length.
class CalorieRing extends StatefulWidget {
  final double consumed;
  final double target;
  final double size;
  final Macros consumedMacros;
  final Macros targetMacros;

  final double? plannedKcal;
  final Macros? plannedMacros;
  final Color ringAccent;
  final int rippleTrigger;

  /// Bumped by the Today tab when it is entered. A change replays the
  /// two-stage fill sweep from zero.
  final int arrivalTrigger;

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
    this.arrivalTrigger = 0,
    this.animateFromZero = true,
  });

  @override
  State<CalorieRing> createState() => _CalorieRingState();
}

class _CalorieRingState extends State<CalorieRing>
    with TickerProviderStateMixin {
  // Near-constant speed, decelerating only near the finish -- the "slow at the
  // end" the sweep is meant to read as.
  static const _arrivalCurve = Curves.easeOut;
  static const _settleCurve = Curves.easeOut;

  /// The from-zero (or from-arrival-trigger) sweep envelope.
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
    value: 1,
  );

  /// Value-to-value smoothing: an eat-toggle changes the kcal AND every macro,
  /// and both the main arc and the three sub-rings glide to the new figures
  /// off this one controller.
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  late double _fromKcal;
  late double _toKcal;
  late double _fromPlannedKcal;
  late double _toPlannedKcal;
  late Macros _fromConsumed;
  late Macros _toConsumed;
  late Macros _fromPlanned;
  late Macros _toPlanned;

  bool _primed = false;

  static Macros _lerpMacros(Macros a, Macros b, double t) => a + (b - a) * t;

  @override
  void initState() {
    super.initState();
    final startZero = widget.animateFromZero;
    _toKcal = widget.consumed;
    _fromKcal = startZero ? 0 : widget.consumed;
    _toPlannedKcal = widget.plannedKcal ?? 0;
    _fromPlannedKcal = startZero ? 0 : (widget.plannedKcal ?? 0);
    _toConsumed = widget.consumedMacros;
    _fromConsumed = startZero ? Macros.zero : widget.consumedMacros;
    _toPlanned = widget.plannedMacros ?? Macros.zero;
    _fromPlanned = startZero ? Macros.zero : (widget.plannedMacros ?? Macros.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_primed) return;
    _primed = true;
    // First mount is itself an arrival.
    _play();
    if (widget.animateFromZero) _startSettle();
  }

  @override
  void didUpdateWidget(covariant CalorieRing old) {
    super.didUpdateWidget(old);
    if (old.arrivalTrigger != widget.arrivalTrigger) _play();

    final valuesChanged = old.consumed != widget.consumed ||
        old.plannedKcal != widget.plannedKcal ||
        old.consumedMacros != widget.consumedMacros ||
        old.plannedMacros != widget.plannedMacros;
    if (valuesChanged) {
      // Re-anchor "from" at wherever the last glide had reached, then aim at
      // the new figures.
      final t = _settleCurve.transform(_settle.value);
      _fromKcal = _lerp(_fromKcal, _toKcal, t);
      _fromPlannedKcal = _lerp(_fromPlannedKcal, _toPlannedKcal, t);
      _fromConsumed = _lerpMacros(_fromConsumed, _toConsumed, t);
      _fromPlanned = _lerpMacros(_fromPlanned, _toPlanned, t);
      _toKcal = widget.consumed;
      _toPlannedKcal = widget.plannedKcal ?? 0;
      _toConsumed = widget.consumedMacros;
      _toPlanned = widget.plannedMacros ?? Macros.zero;
      _startSettle();
    }
  }

  void _play() {
    if (MotionSettings.enabled(context)) {
      _arrival.forward(from: 0);
    } else {
      _arrival.value = 1;
    }
  }

  void _startSettle() {
    if (MotionSettings.enabled(context)) {
      _settle.forward(from: 0);
    } else {
      _settle.value = 1;
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void dispose() {
    _arrival.dispose();
    _settle.dispose();
    super.dispose();
  }

  /// A 0..1 stage envelope: linear rise across [start]..[end] of the sweep,
  /// eased at its own tail.
  double _stage(double t, double start, double end) =>
      _arrivalCurve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final size = widget.size;
    final hasPlanned = widget.plannedKcal != null;

    return AnimatedBuilder(
      animation: Listenable.merge([_arrival, _settle]),
      builder: (context, _) {
        final sweep = _arrival.value;
        final plannedFactor = _stage(sweep, 0.0, 0.58);
        final consumedFactor = _stage(sweep, 0.42, 1.0);

        final st = _settleCurve.transform(_settle.value);
        final smoothKcal = _lerp(_fromKcal, _toKcal, st);
        final smoothPlannedKcal = _lerp(_fromPlannedKcal, _toPlannedKcal, st);
        final smoothConsumed = _lerpMacros(_fromConsumed, _toConsumed, st);
        final smoothPlanned = _lerpMacros(_fromPlanned, _toPlanned, st);

        final shownKcal = smoothKcal * consumedFactor;
        final progress =
            widget.target <= 0 ? 0.0 : shownKcal / widget.target;
        final plannedProgress = (hasPlanned && widget.target > 0)
            ? (smoothPlannedKcal * plannedFactor) / widget.target
            : null;
        final over = progress > 1;
        final remaining = (widget.target - shownKcal).round();

        return RingRipple(
          trigger: widget.rippleTrigger,
          color: widget.ringAccent,
          child: SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                plannedProgress: plannedProgress,
                consumedMacros: smoothConsumed,
                targetMacros: widget.targetMacros,
                plannedMacros: hasPlanned ? smoothPlanned : null,
                ringAccent: widget.ringAccent,
                sweepT: sweep,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shownKcal.round().toString(),
                      style: text.displayLarge?.copyWith(
                        fontSize: size * .19,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -1,
                        fontFeatures: AppTypography.tabular,
                        color: over ? AppPalette.amber : AppPalette.text,
                      ),
                    ),
                    // The captions do not scale with the ring, so on a
                    // collapsed one they spill straight out of the circle.
                    // The big number alone still says everything a compact
                    // ring needs to.
                    if (size > 120) ...[
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
                          '${AppRingLabels.plannedTo} '
                          '${(smoothPlannedKcal * plannedFactor).round()}',
                          style: text.labelSmall
                              ?.copyWith(color: AppPalette.muted),
                        ),
                      ],
                    ],
                    if (size > 145) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MacroStat(
                              color: AppPalette.emerald,
                              grams:
                                  smoothConsumed.protein * consumedFactor),
                          const SizedBox(width: 8),
                          _MacroStat(
                              color: AppPalette.amber,
                              grams: smoothConsumed.carbs * consumedFactor),
                          const SizedBox(width: 8),
                          _MacroStat(
                              color: AppPalette.violet,
                              grams: smoothConsumed.fat * consumedFactor),
                        ],
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

/// One consumed-macro figure inside the ring: a dot in that macro's ring
/// color, then the grams actually eaten today -- the "finished" number the
/// arcs themselves don't spell out.
class _MacroStat extends StatelessWidget {
  final Color color;
  final double grams;

  const _MacroStat({required this.color, required this.grams});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            '${grams.round()}غ',
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.muted,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      );
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

  /// Raw 0..1 arrival progress. The three macro sub-rings derive their own
  /// staggered envelopes from this so they sweep one after another rather
  /// than all with the main arc. Settles at 1. (The main arc's own arrival
  /// envelope is already baked into [progress] / [plannedProgress] by the
  /// widget, along with the value-to-value glide.)
  final double sweepT;

  const _RingPainter({
    required this.progress,
    required this.consumedMacros,
    required this.targetMacros,
    required this.ringAccent,
    this.plannedProgress,
    this.plannedMacros,
    this.sweepT = 1,
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

  /// Per-ring arrival envelope. Ring `i` starts a beat after ring `i-1`, so
  /// the three sweep as a cascade. Settles at 1 once [sweepT] reaches 1.
  double _macroStage(int i, {required bool planned}) {
    final start = (planned ? 0.0 : 0.42) + i * 0.10;
    final end = planned ? start + 0.58 : 1.0;
    return Curves.easeOut
        .transform(((sweepT - start) / (end - start)).clamp(0.0, 1.0));
  }

  void _macroRings(Canvas canvas, Rect rect, double stroke) {
    final consumedRatios = [
      for (var i = 0; i < 3; i++)
        _ratio(
              [consumedMacros.protein, consumedMacros.carbs, consumedMacros.fat][i],
              [targetMacros.protein, targetMacros.carbs, targetMacros.fat][i],
            ) *
            _macroStage(i, planned: false),
    ];
    final planned = plannedMacros;
    final plannedRatios = planned == null
        ? null
        : [
            for (var i = 0; i < 3; i++)
              _ratio(
                    [planned.protein, planned.carbs, planned.fat][i],
                    [
                      targetMacros.protein,
                      targetMacros.carbs,
                      targetMacros.fat
                    ][i],
                  ) *
                  _macroStage(i, planned: true),
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
      old.ringAccent != ringAccent ||
      old.sweepT != sweepT;
}
