import 'dart:async';

import 'package:flutter/material.dart';

import '../../feedback/haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/motion_settings.dart';
import 'burst_particles.dart';

/// The tactile check control used by Today's core eat action.
///
/// Toggling on gets the full tick phrase; undo remains deliberately quiet.
class EatCheck extends StatelessWidget {
  final bool eaten;
  final VoidCallback onToggle;

  const EatCheck({
    required this.eaten,
    required this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final duration = MotionSettings.duration(
      context,
      const Duration(milliseconds: 200),
    );
    return Builder(
        builder: (checkContext) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                unawaited(HapticPhrase.play(
                    eaten ? AppHaptics.untick : AppHaptics.tick));
                onToggle();
                // Undo is intentionally restrained: no burst, only the outline
                // retracting and its quiet haptic phrase.
                if (!eaten) EatBurst.show(checkContext);
              },
              child: AnimatedScale(
                scale: eaten ? 1 : .92,
                duration: duration,
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: duration,
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: eaten ? AppPalette.emerald : Colors.transparent,
                    border: Border.all(
                      color: eaten
                          ? AppPalette.emerald
                          : Colors.white.withValues(alpha: .3),
                      width: 2,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: duration,
                    child: eaten
                        ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey('eaten'),
                            size: 16,
                            color: AppPalette.ink,
                          )
                        : const SizedBox(key: ValueKey('not-eaten')),
                  ),
                ),
              ),
            ));
  }
}
