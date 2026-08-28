import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scale-on-press wrapper.
///
/// Driven by an [AnimationController] rather than [AnimatedScale] so the press
/// and release can carry different curves: the press bites immediately, the
/// release overshoots slightly on the way back. A symmetric implicit tween
/// reads as mush.
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
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 260),
  );

  /// Reversing with a flipped easeOutBack drives the curve slightly below 0,
  /// which the tween maps to a scale just above 1.0 -- the small overshoot on
  /// release is what makes the tap feel physical.
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutBack.flipped,
  ).drive(Tween(begin: 1.0, end: widget.pressedScale));

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (_enabled) _controller.forward();
  }

  void _release() => _controller.reverse();

  @override
  Widget build(BuildContext context) => GestureDetector(
        // Without this, taps landing in a child's transparent padding are
        // swallowed instead of hitting the button.
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapCancel: _release,
        onTapUp: (_) {
          _release();
          if (widget.haptic) HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _release();
                if (widget.haptic) HapticFeedback.mediumImpact();
                widget.onLongPress!.call();
              },
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}
