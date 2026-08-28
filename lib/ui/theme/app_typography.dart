import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The type scale.
///
/// Only one family ships with the app, so the display/body contrast has to be
/// carried by weight and tracking instead of by a second face: display sizes
/// run w800--w900 with negative tracking, body runs w400 at a wide line height.
/// A flat w600-everywhere scale is what makes a screen read as templated.
///
/// If a second family is ever added, the natural split is a Latin display face
/// for numerals -- the app is full of them and Cairo's figures are its least
/// characteristic glyphs.
abstract final class AppTypography {
  static const family = 'Cairo';

  static const _base = TextStyle(fontFamily: family, color: AppPalette.text);

  static TextTheme get textTheme => TextTheme(
        // Hero numerals and screen titles. Tight tracking is what stops large
        // Cairo from looking like a scaled-up paragraph.
        displayLarge: _base.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          height: 1.12,
          letterSpacing: -1.0,
        ),
        displayMedium: _base.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.18,
          letterSpacing: -0.6,
        ),
        headlineMedium: _base.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.28,
          letterSpacing: -0.3,
        ),
        titleLarge: _base.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        titleMedium: _base.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.40,
        ),
        bodyLarge: _base.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.65,
          color: AppPalette.text,
        ),
        bodyMedium: _base.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.60,
          color: AppPalette.muted,
        ),
        labelLarge: _base.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.20,
          letterSpacing: .2,
        ),
        // Eyebrows and section markers. Wide tracking on a small heavy weight
        // is the one place letter-spacing should be positive.
        labelMedium: _base.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.30,
          letterSpacing: 1.1,
          color: AppPalette.muted,
        ),
        labelSmall: _base.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.30,
          color: AppPalette.muted,
        ),
      );

  /// Fixed-width figures. Use on anything that animates or updates in place --
  /// without it a counting number reflows on every frame as digit widths
  /// change.
  static const tabular = [FontFeature.tabularFigures()];
}
