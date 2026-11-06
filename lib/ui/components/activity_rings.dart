import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../theme/motion_settings.dart';

class RingSpec {
  final double progress;
  final Color color;
  final String label;
  const RingSpec(
      {required this.progress, required this.color, required this.label});
}

class ActivityRings extends StatefulWidget {
  final List<RingSpec> rings;
  final double size;
  final double stroke;
  final Widget? center;

  const ActivityRings({
    required this.rings,
    this.size = 180,
    this.stroke = 16,
    this.center,
    super.key,
  });

  @override
  State<ActivityRings> createState() => _ActivityRingsState();
}

class _ActivityRingsState extends State<ActivityRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    value: 1,
  );
  late List<double> _previous = widget.rings.map((r) => r.progress).toList();

  @override
  void didUpdateWidget(covariant ActivityRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.rings.map((r) => r.progress).toList();
    final next = widget.rings.map((r) => r.progress).toList();
    if (!const ListEquality<double>().equals(old, next)) {
      final t = Curves.easeOutCubic.transform(_controller.value);
      _previous = [
        for (var i = 0; i < next.length; i++)
          (i < _previous.length ? _previous[i] : next[i]) +
              ((i < old.length ? old[i] : next[i]) -
                      (i < _previous.length ? _previous[i] : next[i])) *
                  t,
      ];
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = !MotionSettings.enabled(context);
    final values = widget.rings.map((r) => r.progress).toList();
    return Semantics(
      label: widget.rings
          .map((r) => '${r.label} ${(r.progress * 100).round()}٪')
          .join('، '),
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = reduced
                ? 1.0
                : Curves.easeOutCubic.transform(_controller.value);
            final progress = [
              for (var i = 0; i < values.length; i++)
                (i < _previous.length ? _previous[i] : values[i]) +
                    (values[i] -
                            (i < _previous.length ? _previous[i] : values[i])) *
                        t,
            ];
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(widget.size),
                  painter: _RingsPainter(widget.rings, progress, widget.stroke),
                ),
                if (widget.center != null) widget.center!,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final List<RingSpec> rings;
  final List<double> progress;
  final double stroke;
  const _RingsPainter(this.rings, this.progress, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final gap = math.max(3.0, stroke * .25);
    for (var i = 0; i < rings.length; i++) {
      final radius = size.shortestSide / 2 - stroke / 2 - i * (stroke + gap);
      if (radius <= 0) break;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final track = Paint()
        ..color = rings[i].color.withValues(alpha: .14)
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, radius, track);
      final value = progress[i].isFinite ? math.max(0.0, progress[i]) : 0.0;
      final first = value.clamp(0.0, 1.0);
      final paint = Paint()
        ..color = rings[i].color
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (first > 0) {
        canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * first, false, paint);
      }
      final second = (value - 1).clamp(0.0, 1.0);
      if (second > 0) {
        canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * second, false,
            paint..color = Color.lerp(rings[i].color, Colors.black, .28)!);
        final angle = -math.pi / 2 + 2 * math.pi * second;
        canvas.drawCircle(
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
          stroke / 2,
          Paint()..color = rings[i].color.withValues(alpha: .45),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) =>
      old.stroke != stroke ||
      old.rings != rings ||
      !const ListEquality<double>().equals(old.progress, progress);
}
