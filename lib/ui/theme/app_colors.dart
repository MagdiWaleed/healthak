import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const ink = Color(0xFFF5F8F6);
  static const surface = Colors.white;
  static const emerald = Color(0xFF147D64);
  static const mint = Color(0xFF237660);
  static const amber = Color(0xFFA96616);
  static const violet = Color(0xFF7260A4);
  static const text = Color(0xFF193D33);
  static const muted = Color(0xFF62766E);
  static const danger = Color(0xFFBA4141);
  static const outline = Color(0xFFDFE8E2);
  static const soft = Color(0xFFEBF3EE);
  static const onAccent = Colors.white;

  static const accentGradient = LinearGradient(
    colors: [emerald, emerald],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );
}
