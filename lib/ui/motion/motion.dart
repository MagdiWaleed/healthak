import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/motion_settings.dart';

/// A small shared entrance vocabulary for cards and rows.
abstract final class AppMotion {
  static Widget entrance(Widget child, {int index = 0}) =>
      _MotionGate(kind: _MotionKind.entrance, index: index, child: child);

  static Widget pop(Widget child) =>
      _MotionGate(kind: _MotionKind.pop, child: child);
}

Widget entrance(Widget child, {int index = 0}) =>
    AppMotion.entrance(child, index: index);
Widget pop(Widget child) => AppMotion.pop(child);

enum _MotionKind { entrance, pop }

class _MotionGate extends StatelessWidget {
  final Widget child;
  final _MotionKind kind;
  final int index;
  const _MotionGate({required this.child, required this.kind, this.index = 0});

  @override
  Widget build(BuildContext context) {
    if (!MotionSettings.enabled(context)) return child;
    if (kind == _MotionKind.pop) {
      return child.animate().scale(
            begin: const Offset(.9, .9),
            end: const Offset(1, 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
          );
    }
    return child
        .animate(delay: Duration(milliseconds: 40 * index.clamp(0, 20)))
        .fadeIn(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic)
        .slideY(
            begin: .08,
            end: 0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
  }
}
