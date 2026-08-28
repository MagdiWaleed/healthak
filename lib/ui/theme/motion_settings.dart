import 'package:flutter/material.dart';

/// Central reduced-motion gate.
///
/// Phase 1 honours the operating-system accessibility preference immediately.
/// The optional [userEnabled] seam is intentionally not persisted yet: the
/// Settings screen is a Step 4 responsibility and adding a profile field here
/// would violate this plan's no-data-model-change boundary.
abstract final class MotionSettings {
  static bool enabled(BuildContext context, {bool userEnabled = true}) {
    final media = MediaQuery.of(context);
    return userEnabled &&
        !media.disableAnimations &&
        !media.accessibleNavigation;
  }

  static Duration duration(
    BuildContext context,
    Duration value, {
    bool userEnabled = true,
  }) =>
      enabled(context, userEnabled: userEnabled) ? value : Duration.zero;
}
