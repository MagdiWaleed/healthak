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
  static const refractionShift = 2.0;
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
