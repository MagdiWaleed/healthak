import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The emotional weather of a day's progress.
enum DayMood { fresh, building, bloom, over }

/// Mood-specific visual values, resolved once and consumed only by the
/// reactive aurora and calorie ring in Phase 2.
class MoodPalette {
  final DayMood mood;
  final Color emerald;
  final Color ringAccent;
  final double auroraAlphaMultiplier;
  final double auroraSpeedMultiplier;
  final double vignetteAlpha;
  final double grainOpacity;

  const MoodPalette.values({
    required this.mood,
    required this.emerald,
    required this.ringAccent,
    required this.auroraAlphaMultiplier,
    required this.auroraSpeedMultiplier,
    required this.vignetteAlpha,
    required this.grainOpacity,
  });

  /// Resolves the next mood without flip-flopping at the 30%, 95%, and 105%
  /// boundaries. The three-point return bands are deliberate hysteresis.
  static DayMood moodFor(double progress, {DayMood? previous}) {
    final value = progress.clamp(0.0, double.infinity);
    return switch (previous) {
      DayMood.fresh when value < .33 => DayMood.fresh,
      DayMood.building when value > .27 && value < .95 => DayMood.building,
      DayMood.bloom when value >= .92 && value <= 1.08 => DayMood.bloom,
      DayMood.over when value > 1.02 => DayMood.over,
      _ when value < .30 => DayMood.fresh,
      _ when value < .95 => DayMood.building,
      _ when value <= 1.05 => DayMood.bloom,
      _ => DayMood.over,
    };
  }

  factory MoodPalette.forMood(DayMood mood) => switch (mood) {
        DayMood.fresh => MoodPalette.values(
            mood: mood,
            emerald:
                Color.lerp(AppPalette.emerald, const Color(0xFF3CB5B1), .40)!,
            ringAccent: AppPalette.emerald,
            auroraAlphaMultiplier: .85,
            auroraSpeedMultiplier: 1,
            vignetteAlpha: .60,
            grainOpacity: .04,
          ),
        DayMood.building => MoodPalette.values(
            mood: mood,
            emerald: AppPalette.emerald,
            ringAccent: AppPalette.mint,
            auroraAlphaMultiplier: 1,
            auroraSpeedMultiplier: 1.15,
            vignetteAlpha: .55,
            grainOpacity: .04,
          ),
        DayMood.bloom => MoodPalette.values(
            mood: mood,
            emerald: Color.lerp(AppPalette.emerald, AppPalette.amber, .25)!,
            ringAccent: AppPalette.mint,
            auroraAlphaMultiplier: 1.2,
            auroraSpeedMultiplier: 1,
            vignetteAlpha: .42,
            grainOpacity: .055,
          ),
        DayMood.over => MoodPalette.values(
            mood: mood,
            emerald: Color.lerp(AppPalette.violet, AppPalette.amber, .35)!,
            ringAccent: AppPalette.amber,
            auroraAlphaMultiplier: .9,
            auroraSpeedMultiplier: .9,
            vignetteAlpha: .58,
            grainOpacity: .04,
          ),
      };
}
