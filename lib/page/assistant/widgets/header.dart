part of '../assistant_tab.dart';

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: AppStrings.back,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppStrings.assistantTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppPalette.emerald)),
                  const SizedBox(width: 4),
                  const Icon(Icons.eco_rounded,
                      color: AppPalette.emerald, size: 19),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: AppStrings.assistantOptions,
              icon: const Icon(Icons.more_vert, color: AppPalette.muted),
              onSelected: (value) {
                switch (value) {
                  case 'log':
                    pushHealthak(() => const AgentHistoryScreen());
                  case 'history':
                    _SessionListSheet.show(context);
                  case 'new':
                    Get.find<ChatOrchestrator>().startNewSession();
                  case 'model':
                    GlassSheet.show(context,
                        builder: (_) => const GlassSheet(
                              title: AppStrings.assistantModelPickerTooltip,
                              child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: _ModelChip()),
                            ));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'new', child: Text(AppStrings.assistantNewChat)),
                PopupMenuItem(
                    value: 'history',
                    child: Text(AppStrings.assistantHistoryTooltip)),
                PopupMenuItem(
                    value: 'log', child: Text(AppStrings.agentLogTooltip)),
                PopupMenuItem(
                    value: 'model',
                    child: Text(AppStrings.assistantModelPickerTooltip)),
              ],
            ),
          ],
        ),
      );
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Pressable(
          onTap: onTap,
          haptic: true,
          pressedScale: .92,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.soft,
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.outline),
            ),
            child: Icon(icon, size: 16, color: AppPalette.muted),
          ),
        ),
      );
}

/// A one-time, self-collapsing banner pointing at the three header icons --
/// shown once because they landed after the assistant tab already shipped,
/// so nothing else in the UI introduces them to a returning user.
class _HeaderTourBanner extends StatefulWidget {
  final VoidCallback onDismiss;
  const _HeaderTourBanner({required this.onDismiss});

  @override
  State<_HeaderTourBanner> createState() => _HeaderTourBannerState();
}

class _HeaderTourBannerState extends State<_HeaderTourBanner> {
  bool _dismissing = false;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration:
            MotionSettings.duration(context, const Duration(milliseconds: 220)),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _dismissing
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppPalette.violet.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppPalette.violet.withValues(alpha: .28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_upward_rounded,
                        size: 14,
                        color: AppPalette.violet,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          AppStrings.assistantHeaderTourMessage,
                          style: TextStyle(
                            color: AppPalette.text,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                      Pressable(
                        onTap: () => setState(() {
                          _dismissing = true;
                          widget.onDismiss();
                        }),
                        pressedScale: .92,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 4, left: 2),
                          child: Text(
                            AppStrings.assistantHeaderTourDismiss,
                            style: TextStyle(
                              color: AppPalette.violet,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

/// The conversation-thread switcher opened from the header's history icon.
/// Titles are AI-generated from each thread's first message (falling back to
/// a plain truncation) once its first exchange completes.
class _SessionListSheet extends StatelessWidget {
  const _SessionListSheet();

  static Future<void> show(BuildContext context) => GlassSheet.show<void>(
        context,
        builder: (context) => const GlassSheet(
          title: AppStrings.assistantHistoryTitle,
          expand: true,
          child: _SessionListSheet(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final orchestrator = Get.find<ChatOrchestrator>();
    return Obx(() {
      final sessions = orchestrator.sessions.toList(growable: false);
      final activeId = orchestrator.currentSessionId.value;
      if (sessions.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              AppStrings.assistantHistoryEmpty,
              style: TextStyle(color: AppPalette.muted),
            ),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final session = sessions[index];
          final active = session.id == activeId;
          return Pressable(
            onTap: () {
              orchestrator.openSession(session.id);
              Navigator.of(context).pop();
            },
            pressedScale: .98,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: active
                    ? AppPalette.emerald.withValues(alpha: .12)
                    : AppPalette.soft,
                borderRadius: BorderRadius.circular(14),
                border: active
                    ? Border.all(
                        color: AppPalette.emerald.withValues(alpha: .35))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (session.title?.isNotEmpty ?? false)
                              ? session.title!
                              : AppStrings.assistantHistoryUntitled,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                active ? AppPalette.emerald : AppPalette.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _relativeTime(session.updatedAt),
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () => orchestrator.deleteSession(session.id),
                    pressedScale: .9,
                    child: Tooltip(
                      message: AppStrings.assistantHistoryDeleteTooltip,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppPalette.muted.withValues(alpha: .7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${time.year}/${time.month}/${time.day}';
  }
}
