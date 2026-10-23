import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/motion_settings.dart';

/// The only spring vocabulary used by interactive UI.
abstract final class AppSprings {
  static const snappy = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 28,
  );
  static const bouncy = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 14,
  );
  static const gentle = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 22,
  );
  static const wobbly = SpringDescription(
    mass: 1,
    stiffness: 220,
    damping: 10,
  );
}

/// A spring-driven scale for controls whose state is owned elsewhere.
class SpringScale extends StatefulWidget {
  final Widget child;
  final bool pressed;
  final double pressedScale;
  final SpringDescription spring;

  const SpringScale({
    required this.child,
    required this.pressed,
    super.key,
    this.pressedScale = .96,
    this.spring = AppSprings.snappy,
  });

  @override
  State<SpringScale> createState() => _SpringScaleState();
}

class _SpringScaleState extends State<SpringScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 1,
    value: widget.pressed ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant SpringScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressed != widget.pressed ||
        oldWidget.spring != widget.spring) {
      _animateTo(widget.pressed ? 1 : 0);
    }
  }

  void _animateTo(double target) {
    if (!MotionSettings.enabled(context)) {
      _controller.value = target;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        widget.spring,
        _controller.value,
        target,
        _controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween<double>(begin: 1, end: widget.pressedScale)
            .animate(_controller),
        child: widget.child,
      );
}
