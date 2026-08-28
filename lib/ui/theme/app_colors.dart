import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const ink = Color(0xFF071411);
  static const surface = Color(0xFF0D211C);
  static const emerald = Color(0xFF46E2AE);
  static const mint = Color(0xFFA5F3D4);
  static const amber = Color(0xFFFFC56E);
  static const violet = Color(0xFF9A8CFF);
  static const text = Color(0xFFF4FBF8);
  static const muted = Color(0xFFA7BDB6);
  static const danger = Color(0xFFFF7D78);

  static const accentGradient = LinearGradient(
    colors: [emerald, mint],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );
}
