import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HealthakTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final outgoing =
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn);
    return FadeTransition(
      opacity: incoming,
      child: ScaleTransition(
        scale: Tween(begin: .96, end: 1.0).animate(incoming),
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: .0).animate(outgoing),
          child: ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.04).animate(outgoing),
            child: child,
          ),
        ),
      ),
    );
  }
}
