part of '../assistant_tab.dart';

class _BubbleEntrance extends StatefulWidget {
  final Widget child;
  const _BubbleEntrance({required this.child});

  @override
  State<_BubbleEntrance> createState() => _BubbleEntranceState();
}

class _BubbleEntranceState extends State<_BubbleEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> eased =
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    // Reduced-motion users get the final state on the first frame; everyone
    // else gets the fade-lift.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MotionSettings.enabled(context)) {
        controller.forward();
      } else {
        controller.value = 1;
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: eased,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .04), end: Offset.zero)
              .animate(eased),
          child: widget.child,
        ),
      );
}

class AssistantMessageCard extends StatelessWidget {
  final ChatMessage message;
  final AgentFailureKind? failure;
  final VoidCallback onRetry;
  final Future<void> Function(Uri)? openSource;

  const AssistantMessageCard({
    required this.message,
    required this.failure,
    required this.onRetry,
    this.openSource,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatMessageKind.working) {
      return AssistantToolActivity(messages: [message]);
    }
    if (message.kind == ChatMessageKind.proposal) {
      return _ProposalCard(message: message);
    }
    if (message.kind == ChatMessageKind.receipt) {
      return _ReceiptCard(message: message);
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? null : AppPalette.surface,
            gradient: isUser
                ? const LinearGradient(
                    colors: [AppPalette.emerald, AppPalette.lime],
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: message.text.isEmpty
              ? const _TypingDots()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isError)
                      const Text(AppStrings.agentErrorTitle,
                          style: TextStyle(
                              color: AppPalette.danger,
                              fontWeight: FontWeight.w700)),
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
                                  message.text.split('\n').first,
                                  style: TextStyle(
                                    color: isUser
                                        ? AppPalette.onAccent
                                        : AppPalette.text,
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
                    if (isError && message.text.contains('\n'))
                      Text(message.text.split('\n').skip(1).join(' '),
                          style: const TextStyle(
                              color: AppPalette.muted, fontSize: 11)),
                    if (message.sources.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(AppStrings.agentSources,
                          style:
                              TextStyle(color: AppPalette.muted, fontSize: 12)),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        for (final source in message.sources)
                          ActionChip(
                            label: Text(
                                Uri.tryParse(source.url)?.host ?? source.url),
                            onPressed: () async {
                              final uri = Uri.tryParse(source.url);
                              if (uri != null &&
                                  ['http', 'https'].contains(uri.scheme)) {
                                if (openSource != null) {
                                  await openSource!(uri);
                                } else {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              }
                            },
                          ),
                      ]),
                    ],
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
          backgroundColor: AppPalette.raised,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppPalette.soft,
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

/// A pending write's confirmation card. تأكيد executes it through the
/// registry; إلغاء dismisses it with nothing written. Once resolved
/// (confirmed elsewhere producing a receipt, cancelled, or superseded by a
/// newer proposal) it renders as a flat, buttonless summary instead.
