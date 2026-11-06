import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const ink = Color(0xFF0B0F0E);
  static const surface = Color(0xFF141A18);
  static const raised = Color(0xFF1C2421);
  static const emerald = Color(0xFF2EE6A6);
  static const mint = Color(0xFF1FB583);
  static const lime = Color(0xFFC6F432);
  static const coral = Color(0xFFFF6B5B);
  static const amber = Color(0xFFFFB547);
  static const violet = Color(0xFF9B8CFF);
  static const text = Color(0xFFECF5F1);
  static const muted = Color(0xFF8A9A94);
  static const danger = Color(0xFFFF5A5F);
  static const outline = Color(0xFF26302C);
  static const soft = Color(0xFF18221F);
  static const onAccent = Color(0xFF04140E);
  static const ringCalories = emerald;
  static const ringTraining = coral;
  static const ringProtein = violet;
  static const protein = violet;
  static const carbs = amber;
  static const fat = coral;

  static const accentGradient = LinearGradient(
    colors: [emerald, lime],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
            color: color.withValues(alpha: .28),
            blurRadius: 18,
            spreadRadius: 1),
      ];
}
