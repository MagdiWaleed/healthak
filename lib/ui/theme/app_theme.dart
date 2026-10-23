import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: AppPalette.ink,
        colorScheme: const ColorScheme.light(
          primary: AppPalette.emerald,
          onPrimary: AppPalette.onAccent,
          secondary: AppPalette.amber,
          surface: AppPalette.surface,
          onSurface: AppPalette.text,
          error: AppPalette.danger,
          outline: AppPalette.outline,
        ),
        textTheme: AppTypography.textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppPalette.ink,
          foregroundColor: AppPalette.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppPalette.surface,
          labelStyle: const TextStyle(color: AppPalette.muted),
          hintStyle: const TextStyle(color: AppPalette.muted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.outline),
          ),
        ),
        dividerTheme: const DividerThemeData(color: AppPalette.outline),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppPalette.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppPalette.soft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppPalette.surface,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: AppPalette.surface,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
}
