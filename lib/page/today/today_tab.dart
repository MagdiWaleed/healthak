import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../domain/day/day_log.dart';
import '../../service/auth_service.dart';
import '../../ui/components/calorie_ring.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/error_state.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import 'edit_entry_sheet.dart';
import 'quick_add_sheet.dart';
import 'today_controller.dart';

const _weekdayLabels = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

/// The home tab: greeting, a week strip, the calorie ring, and today's
/// entries grouped by slot. Registered in [Get] (not just held locally) so
/// [HomeShell]'s FAB can reach [TodayController] to open the quick-add menu
/// without threading a callback through every tab.
class TodayTab extends StatefulWidget {
  const TodayTab({super.key});

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  late final TodayController controller = Get.put(
    TodayController(uid: Get.find<AuthService>().currentUser!.uid),
  );

  @override
  void dispose() {
    Get.delete<TodayController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        if (controller.loading.value && controller.day.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = controller.error.value;
        if (error != null && controller.day.value == null) {
          return ErrorState(message: error, onRetry: controller.retry);
        }
        final day = controller.day.value;
        if (day == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final sections = <Widget>[
          _Greeting(date: controller.selectedDate.value),
          const SizedBox(height: AppSpacing.md),
          _WeekStrip(controller: controller),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: CalorieRing(
              consumed: day.consumedKcal,
              target: day.targets.kcal,
              consumedMacros: day.consumedTotals,
              targetMacros: day.targets.macros,
              // A ring rebuilt on every eat-toggle shouldn't re-sweep from
              // zero every time -- only the very first render does.
              animateFromZero: false,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (day.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: [
                  const EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: 'لا توجد وجبات اليوم',
                    message: 'ابدأ يومك بإضافة وجبة أو مكوّن',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: controller.isViewingToday
                        ? () => QuickAddSheet.show(context, controller)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('إضافة الآن'),
                  ),
                ],
              ),
            )
          else
            for (final slot in day.activeSlots) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(slot.labelAr,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppPalette.emerald)),
              ),
              for (final entry in day.entriesForSlot(slot)) ...[
                _EntryTile(controller: controller, entry: entry),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xs),
            ],
        ];

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(22, 66, 22, 130),
          itemCount: sections.length,
          itemBuilder: (context, i) =>
              StaggeredEntry(index: i, maxStaggered: 8, child: sections[i]),
        );
      });
}

class _Greeting extends StatelessWidget {
  final DateTime date;
  const _Greeting({required this.date});

  bool get _isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String get _greeting {
    if (!_isToday) return _weekdayFullNames[date.weekday - 1];
    final hour = DateTime.now().hour;
    return hour < 18 ? 'صباح الخير' : 'مساء الخير';
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_greeting, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            _isToday ? 'خطتك الغذائية واضحة أمامك' : 'استعراض يوم سابق',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      );
}

const _weekdayFullNames = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

class _WeekStrip extends StatelessWidget {
  final TodayController controller;
  const _WeekStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Monday of the current week through Sunday. Browsing beyond this range
    // is what History (a full calendar) is for.
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];

    return SizedBox(
      height: 64,
      child: Obx(() {
        final selected = controller.selectedDate.value;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final date = days[i];
            final isSelected = date.year == selected.year &&
                date.month == selected.month &&
                date.day == selected.day;
            final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
            return GestureDetector(
              onTap: isFuture ? null : () => controller.selectDate(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppPalette.emerald.withValues(alpha: .22)
                      : Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(color: AppPalette.emerald.withValues(alpha: .5))
                      : null,
                ),
                child: Opacity(
                  opacity: isFuture ? .35 : 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_weekdayLabels[date.weekday - 1],
                          style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? AppPalette.emerald
                                  : AppPalette.muted)),
                      const SizedBox(height: 2),
                      Text('${date.day}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppPalette.text
                                  : AppPalette.muted)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final TodayController controller;
  final DayEntry entry;

  const _EntryTile({required this.controller, required this.entry});

  @override
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey(entry.entryId),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppPalette.danger.withValues(alpha: .25),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: const Icon(Icons.delete_outline, color: AppPalette.danger),
        ),
        onDismissed: (_) => controller.deleteEntry(entry.entryId),
        child: GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            EditEntrySheet.show(
              context,
              entry: entry,
              onSave: (items) => controller.updateEntryItems(entry.entryId, items),
            );
          },
          child: GlassCard(
            onTap: () => controller.toggleEaten(entry.entryId),
            child: Row(
              children: [
                _EatCheckbox(eaten: entry.eaten),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: entry.eaten ? .5 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StrikeText(text: entry.name, struck: entry.eaten),
                        const SizedBox(height: 2),
                        Text('${entry.kcal.round()} سعرة',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EatCheckbox extends StatelessWidget {
  final bool eaten;
  const _EatCheckbox({required this.eaten});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: eaten ? AppPalette.emerald : Colors.transparent,
          border: Border.all(
            color: eaten ? AppPalette.emerald : Colors.white.withValues(alpha: .3),
            width: 2,
          ),
        ),
        child: eaten
            ? const Icon(Icons.check_rounded, size: 16, color: AppPalette.ink)
            : null,
      );
}

/// A strike-through that animates in rather than snapping, so ticking an
/// item off reads as an action rather than a state flicker.
class _StrikeText extends StatelessWidget {
  final String text;
  final bool struck;
  const _StrikeText({required this.text, required this.struck});

  @override
  Widget build(BuildContext context) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 1.4,
            width: struck ? double.infinity : 0,
            color: AppPalette.muted,
          ),
        ],
      );
}
