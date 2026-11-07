import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => dark;

  static ThemeData get dark {
    final rounded = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppPalette.outline),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: AppPalette.ink,
      colorScheme: const ColorScheme.dark(
        primary: AppPalette.emerald,
        onPrimary: AppPalette.onAccent,
        secondary: AppPalette.lime,
        onSecondary: AppPalette.onAccent,
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
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        labelStyle: const TextStyle(color: AppPalette.muted),
        hintStyle: const TextStyle(color: AppPalette.muted),
        border: rounded,
        enabledBorder: rounded,
        focusedBorder: rounded.copyWith(
          borderSide: const BorderSide(color: AppPalette.emerald, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppPalette.outline),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.emerald.withValues(alpha: .18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.raised,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: AppPalette.raised),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppPalette.raised,
        contentTextStyle: TextStyle(color: AppPalette.text),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.emerald,
          foregroundColor: AppPalette.onAccent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.emerald,
          side: const BorderSide(color: AppPalette.emerald),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.emerald),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppPalette.emerald : null),
        checkColor: const WidgetStatePropertyAll(AppPalette.onAccent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppPalette.onAccent
                : AppPalette.muted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppPalette.emerald
                : AppPalette.raised),
        trackOutlineColor: const WidgetStatePropertyAll(AppPalette.muted),
      ),
      sliderTheme: const SliderThemeData(activeTrackColor: AppPalette.emerald),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppPalette.text),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppPalette.soft
                  : AppPalette.surface),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppPalette.soft,
        selectedColor: AppPalette.emerald,
        labelStyle: TextStyle(color: AppPalette.text),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppPalette.emerald),
    );
  }
}
