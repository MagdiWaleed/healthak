import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/mood_palette.dart';
import 'aurora_background.dart';

/// Makes the shared aurora reflect daily progress without introducing blur or
/// another painter. It only lerps values passed to [AuroraBackground].
class ReactiveAurora extends StatefulWidget {
  final Widget child;
  final DayMood mood;
  final bool animate;
  final bool showGrain;
  final double speedScale;

  const ReactiveAurora({
    required this.child,
    required this.mood,
    super.key,
    this.animate = true,
    this.showGrain = true,
    this.speedScale = 1,
  });

  @override
  State<ReactiveAurora> createState() => _ReactiveAuroraState();
}

class _ReactiveAuroraState extends State<ReactiveAurora>
    with SingleTickerProviderStateMixin {
  late MoodPalette _from = MoodPalette.forMood(widget.mood);
  late MoodPalette _to = _from;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant ReactiveAurora oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _from = _interpolatedPalette;
      _to = MoodPalette.forMood(widget.mood);
      _controller.forward(from: 0);
    }
  }

  MoodPalette get _interpolatedPalette => _lerpPalette(
        _from,
        _to,
        Curves.easeInOut.transform(_controller.value),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final palette = _interpolatedPalette;
          return AuroraBackground(
            animate: widget.animate,
            showGrain: widget.showGrain,
            speedScale: widget.speedScale / palette.auroraSpeedMultiplier,
            blobColors: _blobColors(palette),
            blobAlphaMultiplier: palette.auroraAlphaMultiplier,
            vignetteAlpha: palette.vignetteAlpha,
            grainOpacity: palette.grainOpacity,
            child: widget.child,
          );
        },
      );

  List<Color> _blobColors(MoodPalette palette) => [
        palette.emerald,
        Color.lerp(AppPalette.violet, palette.emerald, .12)!,
        Color.lerp(AppPalette.amber, palette.emerald, .08)!,
        Color.lerp(AppPalette.mint, palette.emerald, .10)!,
      ];

  MoodPalette _lerpPalette(MoodPalette a, MoodPalette b, double t) =>
      MoodPalette.values(
        mood: b.mood,
        emerald: Color.lerp(a.emerald, b.emerald, t)!,
        ringAccent: Color.lerp(a.ringAccent, b.ringAccent, t)!,
        auroraAlphaMultiplier:
            lerpDouble(a.auroraAlphaMultiplier, b.auroraAlphaMultiplier, t)!,
        auroraSpeedMultiplier:
            lerpDouble(a.auroraSpeedMultiplier, b.auroraSpeedMultiplier, t)!,
        vignetteAlpha: lerpDouble(a.vignetteAlpha, b.vignetteAlpha, t)!,
        grainOpacity: lerpDouble(a.grainOpacity, b.grainOpacity, t)!,
      );
}
