import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/motion_settings.dart';

/// A short, deterministic burst that is mounted in the root overlay so it can
/// escape an entry row's bounds. Only one row burst is allowed at a time.
abstract final class EatBurst {
  static OverlayEntry? _active;

  static void show(BuildContext context) {
    _dismiss();
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (box == null) return;
    final point = box.localToGlobal(box.size.center(Offset.zero));
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: point.dx - 48,
        top: point.dy - 48,
        child: IgnorePointer(
          child: RepaintBoundary(
            child: _Burst(onDone: () => _dismiss(entry)),
          ),
        ),
      ),
    );
    _active = entry;
    overlay.insert(entry);
  }

  /// Takes the current burst down exactly once.
  ///
  /// A burst was removed from two places -- the next tap superseding it, and
  /// its own animation finishing -- with nothing stopping both from firing for
  /// the same entry. Ticking two items off inside half a second removed one
  /// twice and Flutter asserted, which is the error that flashed over the
  /// Today tab on a quick double toggle.
  static void _dismiss([OverlayEntry? only]) {
    final active = _active;
    if (active == null) return;
    if (only != null && !identical(only, active)) return;
    _active = null;
    if (active.mounted) active.remove();
  }
}

class _Burst extends StatefulWidget {
  final VoidCallback onDone;
  const _Burst({required this.onDone});

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 96,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            painter: _BurstPainter(
              progress: MotionSettings.enabled(context) ? _controller.value : 1,
            ),
          ),
        ),
      );
}

class _BurstPainter extends CustomPainter {
  final double progress;
  const _BurstPainter({required this.progress});

  static final _random = math.Random(2411);
  static final _particles = List.generate(12, (i) {
    final angle = (math.pi * 2 * i / 12) + (_random.nextDouble() - .5) * .3;
    return (
      angle: angle,
      speed: 22 + _random.nextDouble() * 30,
      size: 2 + _random.nextDouble() * 2
    );
  });
  static const _colors = [AppPalette.emerald, AppPalette.mint, Colors.white];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final t = Curves.easeOutCubic.transform(progress);
    final alpha = (1 - ((progress - .65) / .35).clamp(0.0, 1.0)) * .9;
    for (var i = 0; i < _particles.length; i++) {
      final particle = _particles[i];
      final distance = particle.speed * t;
      final point = Offset(
        centre.dx + math.cos(particle.angle) * distance,
        centre.dy + math.sin(particle.angle) * distance + 22 * t * t,
      );
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: alpha);
      if (i % 4 == 0) {
        canvas.drawRect(
            Rect.fromCenter(
                center: point, width: particle.size * 2, height: particle.size),
            paint);
      } else {
        canvas.drawCircle(point, particle.size, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
