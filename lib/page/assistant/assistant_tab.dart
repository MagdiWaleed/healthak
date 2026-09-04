import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';

import '../../l10n/app_strings.dart';
import '../../service/agent/agent_model_catalog.dart';
import '../../service/agent/agent_models.dart';
import '../../service/agent/chat_orchestrator.dart';
import '../../service/prefs_service.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/pressable.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/glass_tokens.dart';
import '../../ui/theme/motion_settings.dart';

class AssistantTab extends StatefulWidget {
  const AssistantTab({super.key});

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  late final ChatOrchestrator orchestrator = Get.find<ChatOrchestrator>();
  late final PrefsService prefs = Get.find<PrefsService>();
  final composer = TextEditingController();
  final scroll = ScrollController();
  Worker? _messageWorker;
  late bool disclosureAccepted;

  @override
  void initState() {
    super.initState();
    disclosureAccepted = prefs.assistantDisclosureAccepted;
    _messageWorker = ever(orchestrator.messages, (_) => _scrollToEnd());
  }

  @override
  void dispose() {
    _messageWorker?.dispose();
    composer.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: MotionSettings.duration(
          context,
          const Duration(milliseconds: 240),
        ),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _acceptDisclosure() async {
    await prefs.acceptAssistantDisclosure();
    if (mounted) setState(() => disclosureAccepted = true);
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? composer.text).trim();
    if (text.isEmpty || orchestrator.sending.value) return;
    composer.clear();
    FocusScope.of(context).unfocus();
    await orchestrator.send(text);
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const _AssistantHeader(),
          Expanded(
            child: Obx(() {
              final messages = orchestrator.messages.toList(growable: false);
              if (messages.isEmpty) {
                return _EmptyConversation(active: orchestrator.sending.value);
              }
              return ListView.builder(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                itemCount: messages.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MessageCard(
                    message: messages[index],
                    failure: index == messages.length - 1
                        ? orchestrator.lastFailure.value
                        : null,
                    onRetry: orchestrator.retryLast,
                  ),
                ),
              );
            }),
          ),
          if (!disclosureAccepted)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: _DisclosureCard(onAccept: _acceptDisclosure),
            )
          else ...[
            _SuggestionRail(onSelected: _send),
            _Composer(
              controller: composer,
              sending: orchestrator.sending,
              onSend: _send,
            ),
          ],
          const SizedBox(height: 98),
        ],
      );
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _AgentPulse(size: 50, compact: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.assistant,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    AppStrings.assistantPrivacyNote,
                    style: TextStyle(color: AppPalette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const _ModelChip(),
          ],
        ),
      );
}

/// Tappable pill in the header that lets the user switch xAI model. The choice
/// is persisted per-device and picked up on the next turn.
class _ModelChip extends StatefulWidget {
  const _ModelChip();

  @override
  State<_ModelChip> createState() => _ModelChipState();
}

class _ModelChipState extends State<_ModelChip> {
  final PrefsService _prefs = Get.find<PrefsService>();
  late String _selectedId = _prefs.assistantModelId;

  Future<void> _pick(String id) async {
    await _prefs.setAssistantModelId(id);
    if (mounted) setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final selected = AgentModels.byId(_selectedId);
    return PopupMenuButton<String>(
      tooltip: AppStrings.assistantModelPickerTooltip,
      initialValue: selected.id,
      onSelected: _pick,
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        for (final model in AgentModels.all)
          PopupMenuItem<String>(
            value: model.id,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.label,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  model.noteAr,
                  style: const TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 5, 6, 5),
        decoration: BoxDecoration(
          color: AppPalette.violet.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppPalette.violet.withValues(alpha: .35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.label,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: AppPalette.violet,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              size: 13,
              color: AppPalette.violet,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  final bool active;
  const _EmptyConversation({required this.active});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AgentPulse(active: active),
              const SizedBox(height: 24),
              Text(
                AppStrings.assistantHeadline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.assistantEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}

class _DisclosureCard extends StatelessWidget {
  final Future<void> Function() onAccept;
  const _DisclosureCard({required this.onAccept});

  @override
  Widget build(BuildContext context) => GlassCard(
        elevation: GlassElevation.panel,
        highlighted: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.emerald.withValues(alpha: .14),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppPalette.emerald,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  AppStrings.assistantDisclosureTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              AppStrings.assistantDisclosureBody,
              style: TextStyle(color: AppPalette.muted, height: 1.6),
            ),
            const SizedBox(height: 14),
            GlassButton(
              label: AppStrings.assistantDisclosureConfirm,
              icon: Icons.arrow_back_rounded,
              onPressed: onAccept,
            ),
          ],
        ),
      );
}

class _SuggestionRail extends StatelessWidget {
  final Future<void> Function(String text) onSelected;
  const _SuggestionRail({required this.onSelected});

  static const suggestions = [
    AppStrings.assistantSuggestionRemaining,
    AppStrings.assistantSuggestionToday,
    AppStrings.assistantSuggestionProtein,
    AppStrings.assistantSuggestionWeek,
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => Pressable(
            haptic: true,
            onTap: () => onSelected(suggestions[index]),
            pressedScale: .96,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .15),
                ),
              ),
              child: Text(
                suggestions[index],
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final RxBool sending;
  final Future<void> Function() onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        child: GlassCard(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 5, 6, 5),
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: AppStrings.assistantComposerHint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ),
              Obx(() => Pressable(
                    onTap: sending.value ? null : onSend,
                    haptic: true,
                    pressedScale: .90,
                    child: AnimatedContainer(
                      duration: MotionSettings.duration(
                        context,
                        const Duration(milliseconds: 180),
                      ),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            sending.value ? null : AppPalette.accentGradient,
                        color: sending.value
                            ? Colors.white.withValues(alpha: .08)
                            : null,
                      ),
                      child: sending.value
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppPalette.emerald,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              color: AppPalette.ink,
                            ),
                    ),
                  )),
            ],
          ),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  final ChatMessage message;
  final AgentFailureKind? failure;
  final VoidCallback onRetry;

  const _MessageCard({
    required this.message,
    required this.failure,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatMessageKind.working) {
      return _ToolReadCard(message: message);
    }
    final isUser = message.kind == ChatMessageKind.user;
    final isError = message.status == ChatMessageStatus.error;
    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        child: GlassCard(
          tint: isError
              ? failure == AgentFailureKind.quota
                  ? AppPalette.violet
                  : AppPalette.danger
              : isUser
                  ? AppPalette.emerald
                  : null,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(20),
            topEnd: const Radius.circular(20),
            bottomStart: Radius.circular(isUser ? 5 : 20),
            bottomEnd: Radius.circular(isUser ? 20 : 5),
          ).resolve(Directionality.of(context)),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: message.text.isEmpty
              ? const _TypingDots()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isError) ...[
                          Icon(
                            failure == AgentFailureKind.quota
                                ? Icons.schedule_rounded
                                : failure == AgentFailureKind.offline
                                    ? Icons.wifi_off_rounded
                                    : Icons.refresh_rounded,
                            size: 17,
                            color: failure == AgentFailureKind.quota
                                ? AppPalette.violet
                                : AppPalette.danger,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: isError || isUser
                              ? Text(
                                  message.text,
                                  style: const TextStyle(
                                    color: AppPalette.text,
                                    height: 1.55,
                                  ),
                                )
                              : _MarkdownBody(text: message.text),
                        ),
                        if (message.status == ChatMessageStatus.streaming) ...[
                          const SizedBox(width: 5),
                          const _StreamingCursor(),
                        ],
                      ],
                    ),
                    if (isError && failure != AgentFailureKind.quota) ...[
                      const SizedBox(height: 7),
                      Pressable(
                        onTap: onRetry,
                        pressedScale: .96,
                        child: const Text(
                          AppStrings.assistantRetry,
                          style: TextStyle(
                            color: AppPalette.emerald,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Renders assistant replies (bold, lists, code) instead of raw `**`/`-`
/// markers. User and error bubbles stay plain text.
class _MarkdownBody extends StatelessWidget {
  final String text;
  const _MarkdownBody({required this.text});

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(color: AppPalette.text, height: 1.55);
    return MarkdownBody(
      data: text,
      shrinkWrap: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        p: body,
        strong: body.copyWith(fontWeight: FontWeight.w800),
        em: body.copyWith(fontStyle: FontStyle.italic),
        listBullet: body.copyWith(color: AppPalette.emerald),
        h1: Theme.of(context).textTheme.titleLarge,
        h2: Theme.of(context).textTheme.titleMedium,
        h3: Theme.of(context).textTheme.titleSmall,
        code: body.copyWith(
          fontFamily: 'monospace',
          fontSize: 12.5,
          color: AppPalette.mint,
          backgroundColor: Colors.white.withValues(alpha: .08),
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(10),
        ),
        blockquote: body.copyWith(color: AppPalette.muted),
        blockquoteDecoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: AppPalette.emerald.withValues(alpha: .4),
              width: 3,
            ),
          ),
        ),
        blockSpacing: 8,
      ),
    );
  }
}

class _ToolReadCard extends StatelessWidget {
  final ChatMessage message;
  const _ToolReadCard({required this.message});

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .72,
          ),
          child: GlassCard(
            elevation: GlassElevation.flush,
            tint: message.status == ChatMessageStatus.error
                ? AppPalette.danger
                : AppPalette.emerald,
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.emerald.withValues(alpha: .12),
                        border: Border.all(
                          color: AppPalette.emerald.withValues(alpha: .35),
                        ),
                      ),
                      child: Icon(
                        message.status == ChatMessageStatus.complete
                            ? Icons.check_rounded
                            : Icons.auto_awesome_rounded,
                        color: message.status == ChatMessageStatus.error
                            ? AppPalette.danger
                            : AppPalette.emerald,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        message.text,
                        style: const TextStyle(
                          color: AppPalette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (message.status == ChatMessageStatus.streaming) ...[
                  const SizedBox(height: 9),
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppPalette.emerald,
                    backgroundColor: Colors.transparent,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
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
                child: Transform.scale(
                  scale: .7 +
                      .3 *
                          math
                              .sin((controller.value * math.pi * 2) - i * .8)
                              .abs(),
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
  final double size;
  final bool active;
  final bool compact;

  const _AgentPulse({
    this.size = 132,
    this.active = false,
    this.compact = false,
  });

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
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _AgentPulsePainter(
              phase: controller.value,
              active: widget.active,
              compact: widget.compact,
            ),
          ),
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
    canvas.drawArc(rect, start, active ? math.pi * 1.18 : math.pi * 2, false, sweep);

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
