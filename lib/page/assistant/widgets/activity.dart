part of '../assistant_tab.dart';

class AssistantToolActivity extends StatefulWidget {
  final List<ChatMessage> messages;
  const AssistantToolActivity({required this.messages, super.key});

  @override
  State<AssistantToolActivity> createState() => AssistantToolActivityState();
}

class AssistantToolActivityState extends State<AssistantToolActivity> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final running = widget.messages
        .any((message) => message.status == ChatMessageStatus.streaming);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
        child: running || expanded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final message in widget.messages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Chip(
                        avatar: Icon(
                            message.status == ChatMessageStatus.complete
                                ? Icons.check_rounded
                                : Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppPalette.emerald),
                        label: Text(message.text),
                        backgroundColor: AppPalette.surface,
                        side: const BorderSide(color: AppPalette.outline),
                      ),
                    ),
                  if (running) const ShimmerBox(height: 3, width: 110),
                  if (!running)
                    TextButton(
                      onPressed: () => setState(() => expanded = false),
                      child: Text(
                          AppStrings.agentToolsUsed(widget.messages.length)),
                    ),
                ],
              )
            : TextButton.icon(
                onPressed: () => setState(() => expanded = true),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(AppStrings.agentToolsUsed(widget.messages.length)),
              ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionSettings.enabled(context)) {
      if (!controller.isAnimating) controller.repeat();
    } else {
      controller.stop();
      controller.value = 1;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.translate(
                  offset: Offset(
                      0,
                      -3 *
                          math
                              .sin((controller.value * math.pi * 2) - i * .8)
                              .abs()),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.emerald.withValues(alpha: .8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionSettings.enabled(context)) {
      if (!controller.isAnimating) controller.repeat(reverse: true);
    } else {
      controller.stop();
      controller.value = 1;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: controller.drive(Tween(begin: .25, end: 1.0)),
        child: Container(
          width: 2,
          height: 15,
          decoration: BoxDecoration(
            color: AppPalette.emerald,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
}

class _AgentPulse extends StatefulWidget {
  final bool active;

  const _AgentPulse({
    this.active = false,
  });

  static const double _size = 132;

  @override
  State<_AgentPulse> createState() => _AgentPulseState();
}

class _AgentPulseState extends State<_AgentPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AgentPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.active && MotionSettings.enabled(context)) {
      if (!controller.isAnimating) controller.repeat();
    } else {
      controller.stop();
      controller.value = .66;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: SizedBox.square(
          dimension: 186,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 186,
              height: 186,
              decoration: const BoxDecoration(
                  color: AppPalette.soft, shape: BoxShape.circle),
            ),
            Container(
              width: 158,
              height: 158,
              decoration: const BoxDecoration(
                  color: AppPalette.raised, shape: BoxShape.circle),
            ),
            Container(
              width: 126,
              height: 126,
              decoration: const BoxDecoration(
                  color: AppPalette.emerald, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 56, color: AppPalette.onAccent),
            ),
            if (widget.active)
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) => CustomPaint(
                  size: const Size.square(_AgentPulse._size),
                  painter: _AgentPulsePainter(
                    phase: controller.value,
                    active: true,
                    compact: false,
                  ),
                ),
              ),
          ]),
        ),
      );
}

class _AgentPulsePainter extends CustomPainter {
  final double phase;
  final bool active;
  final bool compact;

  const _AgentPulsePainter({
    required this.phase,
    required this.active,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final unit = size.shortestSide;
    final pulse = active ? math.sin(phase * math.pi * 4) * .035 : 0.0;
    final rect = Rect.fromCircle(center: center, radius: unit * (.40 + pulse));
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppPalette.emerald.withValues(alpha: compact ? .18 : .28),
          AppPalette.emerald.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: unit * .52));
    canvas.drawCircle(center, unit * .52, glow);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 2.2 : 5
      ..strokeCap = StrokeCap.round
      ..color = AppPalette.emerald.withValues(alpha: .14);
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 2.5 : 6
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          AppPalette.emerald,
          AppPalette.mint,
          AppPalette.violet,
          AppPalette.emerald,
        ],
      ).createShader(rect);
    final start = -math.pi / 2 + phase * math.pi * 2;
    // At rest: a closed, static ring (a logo). While working: an open arc
    // chasing a dot around the ring (a spinner) — the two must read
    // differently, or an idle icon looks like a stuck loading spinner.
    canvas.drawArc(
        rect, start, active ? math.pi * 1.18 : math.pi * 2, false, sweep);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 1.4 : 3
      ..color = AppPalette.mint.withValues(alpha: .55);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * .27),
      -start * .62,
      math.pi * .72,
      false,
      inner,
    );

    if (active) {
      final dotAngle = start + math.pi * 1.18;
      final dot = center +
          Offset(math.cos(dotAngle), math.sin(dotAngle)) * rect.width / 2;
      canvas.drawCircle(
        dot,
        compact ? 2.5 : 5,
        Paint()..color = AppPalette.text,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AgentPulsePainter oldDelegate) =>
      phase != oldDelegate.phase ||
      active != oldDelegate.active ||
      compact != oldDelegate.compact;
}
