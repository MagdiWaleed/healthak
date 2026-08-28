import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../feedback/haptics.dart';
import '../theme/motion_settings.dart';
import 'spring.dart';

/// Scale-on-press wrapper.
///
/// The existing gesture API stays intact while its internal controller follows
/// the shared snappy spring, so every press and release settles consistently.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far to shrink. Small targets need less; a full-width button needs
  /// less than a chip or the effect looks like the screen is flexing.
  final double pressedScale;

  final bool haptic;

  const Pressable({
    required this.child,
    super.key,
    this.onTap,
    this.onLongPress,
    this.pressedScale = .96,
    this.haptic = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
  );

  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: widget.pressedScale).animate(_controller);

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    if (!MotionSettings.enabled(context)) {
      _controller.value = target;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        AppSprings.snappy,
        _controller.value,
        target,
        _controller.velocity,
      ),
    );
  }

  void _down(TapDownDetails _) {
    if (_enabled) _animateTo(1);
  }

  void _release() => _animateTo(0);

  @override
  Widget build(BuildContext context) => GestureDetector(
        // Without this, taps landing in a child's transparent padding are
        // swallowed instead of hitting the button.
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapCancel: _release,
        onTapUp: (_) {
          _release();
          if (widget.haptic) {
            unawaited(HapticPhrase.play(AppHaptics.step));
          }
          widget.onTap?.call();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _release();
                if (widget.haptic) {
                  unawaited(HapticPhrase.play(AppHaptics.lift));
                }
                widget.onLongPress!.call();
              },
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}
