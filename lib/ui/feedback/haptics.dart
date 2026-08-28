import 'dart:async';

import 'package:flutter/services.dart';

/// The app's complete physical-feedback vocabulary.
enum AppHaptics { tick, untick, step, lift, land, goal, error, celebrate }

/// Central haptic phrases with one rate limiter for high-frequency controls.
abstract final class HapticPhrase {
  static DateTime? _lastStepAt;

  static Future<void> play(AppHaptics phrase) async {
    if (phrase == AppHaptics.step && !_mayPlayStep()) return;

    switch (phrase) {
      case AppHaptics.tick:
        await HapticFeedback.selectionClick();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await HapticFeedback.lightImpact();
        return;
      case AppHaptics.untick:
      case AppHaptics.step:
        await HapticFeedback.selectionClick();
        return;
      case AppHaptics.lift:
        await HapticFeedback.mediumImpact();
        return;
      case AppHaptics.land:
        await HapticFeedback.lightImpact();
        return;
      case AppHaptics.goal:
        await _goal();
        return;
      case AppHaptics.error:
        await HapticFeedback.heavyImpact();
        return;
      case AppHaptics.celebrate:
        await _goal();
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          await HapticFeedback.selectionClick();
        }
        return;
    }
  }

  static bool _mayPlayStep() {
    final now = DateTime.now();
    final last = _lastStepAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 80)) {
      return false;
    }
    _lastStepAt = now;
    return true;
  }

  static Future<void> _goal() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }
}
