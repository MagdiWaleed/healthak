enum GlassElevation { flush, card, panel, hero }

abstract final class GlassTokens {
  static const blur = 20.0;
  static const panelTint = 0.18;
  static const cardTint = 0.11;
  static const borderAlpha = 0.22;
  static const specularAlpha = 0.30;
  static const elevationNone = 0.0;
  static const elevationLow = 8.0;
  static const elevationMedium = 18.0;
  static const elevationHigh = 32.0;

  static const specularSweepDeg = 30.0;
  static const innerGlowAlpha = .06;

  /// Kimi's physical light-source shift per 100px of scroll.
  static const refractionShift = 2.0;

  /// Converts that source displacement into the border painter's angular
  /// coordinate. Treating [refractionShift] itself as degrees made a normal
  /// 100px drag move the highlight only 2 degrees -- less than a tenth of its
  /// own 30-degree width, so it looked stationary.
  static const refractionAngleGain = 9.0;
  static const listSpecularStepDeg = 8.0;
  static const pressedTintDelta = .05;

  static double topTint(GlassElevation level) => switch (level) {
        GlassElevation.flush => cardTint * .6,
        GlassElevation.card => cardTint + .05,
        GlassElevation.panel => panelTint + .02,
        GlassElevation.hero => panelTint + .06,
      };

  static double bottomTint(GlassElevation level) => switch (level) {
        GlassElevation.flush => .035,
        GlassElevation.card => .055,
        GlassElevation.panel => .10,
        GlassElevation.hero => .14,
      };

  static double borderIntensity(GlassElevation level) => switch (level) {
        GlassElevation.flush => .65,
        GlassElevation.card => 1,
        GlassElevation.panel => 1.18,
        GlassElevation.hero => 1.55,
      };
}
