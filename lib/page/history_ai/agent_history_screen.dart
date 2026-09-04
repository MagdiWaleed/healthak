import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../l10n/app_strings.dart';
import '../../service/agent/agent_action_log.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/glass_chip.dart';
import '../../ui/feedback/haptics.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/motion/pressable.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/glass_tokens.dart';
import 'agent_history_controller.dart';

/// «سجل المساعد» -- Phase 5C. The audit trail of every write the agent has
/// actually executed, reverse-chronological, with a per-row تراجع. Distinct
/// from the nutrition history tab (`lib/page/history/`), which this never
/// touches.
class AgentHistoryScreen extends StatefulWidget {
  const AgentHistoryScreen({super.key});

  @override
  State<AgentHistoryScreen> createState() => _AgentHistoryScreenState();
}

class _AgentHistoryScreenState extends State<AgentHistoryScreen> {
  // Plain, screen-scoped controller -- not `Get.put`/a Binding, same
  // pattern as `MealEditorController` and friends elsewhere in the app, so
  // there is no matching `Get.delete` to remember in `dispose()`.
  late final AgentHistoryController controller = AgentHistoryController(
    log: Get.find(),
    tools: Get.find(),
  );

  @override
  void initState() {
    super.initState();
    controller.onInit();
  }

  @override
  Widget build(BuildContext context) => GlassScaffold(
        appBar: AppBar(title: const Text(AppStrings.agentLogTitle)),
        body: Obx(() {
          if (controller.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = controller.entries;
          final filtered = controller.filtered;
          return Column(
            children: [
              const SizedBox(height: 88),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _FilterRow(controller: controller),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: all.isEmpty
                    ? const EmptyState(
                        icon: Icons.fact_check_outlined,
                        title: AppStrings.agentLogEmptyTitle,
                        message: AppStrings.agentLogEmptyMessage,
                      )
                    : _EntryList(entries: filtered, controller: controller),
              ),
            ],
          );
        }),
      );
}

class _FilterRow extends StatelessWidget {
  final AgentHistoryController controller;
  const _FilterRow({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() => Wrap(
        spacing: 8,
        children: [
          for (final value in AgentHistoryFilter.values)
            GlassChip(
              label: _labelFor(value),
              selected: controller.filter.value == value,
              onTap: () => controller.filter.value = value,
            ),
        ],
      ));

  static String _labelFor(AgentHistoryFilter filter) => switch (filter) {
        AgentHistoryFilter.all => AppStrings.agentLogFilterAll,
        AgentHistoryFilter.add => AppStrings.agentLogFilterAdd,
        AgentHistoryFilter.edit => AppStrings.agentLogFilterEdit,
        AgentHistoryFilter.remove => AppStrings.agentLogFilterRemove,
        AgentHistoryFilter.swap => AppStrings.agentLogFilterSwap,
      };
}

class _EntryList extends StatelessWidget {
  final List<AgentActionLogEntry> entries;
  final AgentHistoryController controller;
  const _EntryList({required this.entries, required this.controller});

  @override
  Widget build(BuildContext context) {
    final sections = _groupByDay(entries);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.xs),
              child: Text(
                section.label,
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            for (final entry in section.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Obx(() => _EntryRow(
                      entry: entry,
                      busy: controller.undoingId.value == entry.id,
                      onUndo: () => controller.undo(entry.id),
                    )),
              ),
          ],
        );
      },
    );
  }

  static List<_DaySection> _groupByDay(List<AgentActionLogEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final buckets = <String, List<AgentActionLogEntry>>{};
    final order = <String>[];
    for (final entry in entries) {
      final date = DateTime(
          entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      final label = date == today
          ? AppStrings.agentLogToday
          : date == yesterday
              ? AppStrings.agentLogYesterday
              : '${date.year}/${date.month}/${date.day}';
      if (!buckets.containsKey(label)) order.add(label);
      buckets.putIfAbsent(label, () => []).add(entry);
    }
    return [for (final label in order) _DaySection(label, buckets[label]!)];
  }
}

class _DaySection {
  final String label;
  final List<AgentActionLogEntry> entries;
  const _DaySection(this.label, this.entries);
}

class _EntryRow extends StatelessWidget {
  final AgentActionLogEntry entry;
  final bool busy;
  final VoidCallback onUndo;

  const _EntryRow({
    required this.entry,
    required this.busy,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) => GlassCard(
        elevation: GlassElevation.flush,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _colorFor(entry.category).withValues(alpha: .14),
                border: Border.all(
                  color: _colorFor(entry.category).withValues(alpha: .35),
                ),
              ),
              child: Icon(
                _iconFor(entry.category),
                size: 16,
                color: _colorFor(entry.category),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.humanSummary,
                    style: TextStyle(
                      color: entry.isUndone ? AppPalette.muted : AppPalette.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.5,
                      decoration: entry.isUndone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _relativeTime(entry.timestamp),
                    style: const TextStyle(color: AppPalette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (entry.isUndone)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  AppStrings.agentLogUndone,
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (entry.isUndoable)
              Pressable(
                onTap: busy
                    ? null
                    : () {
                        unawaited(HapticPhrase.play(AppHaptics.land));
                        onUndo();
                      },
                pressedScale: .94,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: busy
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.violet,
                          ),
                        )
                      : const Text(
                          AppStrings.agentLogUndo,
                          style: TextStyle(
                            color: AppPalette.violet,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
          ],
        ),
      );

  static Color _colorFor(AgentActionCategory? category) => switch (category) {
        AgentActionCategory.add => AppPalette.emerald,
        AgentActionCategory.edit => AppPalette.amber,
        AgentActionCategory.remove => AppPalette.danger,
        AgentActionCategory.swap => AppPalette.violet,
        null => AppPalette.muted,
      };

  static IconData _iconFor(AgentActionCategory? category) => switch (category) {
        AgentActionCategory.add => Icons.add_rounded,
        AgentActionCategory.edit => Icons.tune_rounded,
        AgentActionCategory.remove => Icons.remove_rounded,
        AgentActionCategory.swap => Icons.swap_horiz_rounded,
        null => Icons.circle_outlined,
      };

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${time.year}/${time.month}/${time.day}';
  }
}
