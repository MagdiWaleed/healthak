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
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
          scale: Tween(begin: .98, end: 1.0).animate(curved), child: child),
    );
  }
}
