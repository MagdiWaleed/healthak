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
          // Loading has finished (the branch above already returned otherwise)
          // and there is no error, so this is a real, valid state: a past day
          // that was never opened has no document at all -- watch() correctly
          // emits null rather than materializing one. Only `ensureDay` (today
          // only) creates a document; browsing history must never invent one.
          // A bare `CircularProgressIndicator` here would spin forever with
          // no way out.
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Greeting(date: controller.selectedDate.value),
                const SizedBox(height: AppSpacing.lg),
                const EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'لا يوجد سجل لهذا اليوم',
                  message: 'لم يُسجَّل أي شيء في هذا اليوم',
                ),
                // This branch has no week strip -- browsing to a day with no
                // record at all was previously a dead end with no way back
                // except killing and relaunching the app.
                if (!controller.isViewingToday) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextButton.icon(
                    onPressed: () => controller.selectDate(DateTime.now()),
                    icon: const Icon(Icons.today_rounded),
                    label: const Text('العودة لليوم'),
                  ),
                ],
              ],
            ),
          );
        }

        // Every item below carries an explicit, content-stable key -- see
        // the comment on `findChildIndexCallback` further down for why.
        final header = <Widget>[
          _Greeting(key: const ValueKey('greeting'), date: controller.selectedDate.value),
          const SizedBox(key: ValueKey('spacer-greeting'), height: AppSpacing.md),
          _WeekStrip(key: const ValueKey('weekstrip'), controller: controller),
          const SizedBox(key: ValueKey('spacer-weekstrip'), height: AppSpacing.lg),
          Stack(
            key: const ValueKey('ring'),
            alignment: Alignment.topCenter,
            children: [
              Center(
                child: CalorieRing(
                  consumed: day.consumedKcal,
                  target: day.targets.kcal,
                  consumedMacros: day.consumedTotals,
                  targetMacros: day.targets.macros,
                  // The faded band: everything today's plan adds up to, ticked
                  // off or not, so "do I need to add or remove something" is
                  // answerable before it's actually eaten.
                  plannedKcal: day.plannedKcal,
                  plannedMacros: day.plannedTotals,
                  // A ring rebuilt on every eat-toggle shouldn't re-sweep from
                  // zero every time -- only the very first render does.
                  animateFromZero: false,
                ),
              ),
              // A literal top-right screen position, not a text-flow one --
              // this badge floats over the ring regardless of RTL, so a plain
              // `Positioned(right:)` is correct here, not the RTL-flip trap
              // it would be for inline content.
              const Positioned(top: 4, right: 0, child: _RingLegend()),
            ],
          ),
          const SizedBox(key: ValueKey('spacer-ring'), height: AppSpacing.md),
          _TargetSummary(key: const ValueKey('target-summary'), controller: controller),
        ];

        // A `ListView` top-aligns short content, and the FAB is docked at a
        // fixed position near the bottom of the *viewport* regardless of how
        // much content exists -- on a day with no entries the two collided
        // (the CTA below rendered directly under the FAB). `SliverFillRemaining`
        // centers short content in the true remaining viewport instead, and
        // the populated branch still scrolls normally past it.
        if (day.isEmpty) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 66, 22, 0),
                sliver: SliverList.list(children: header),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, AppSpacing.lg, 22, 130),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                  ),
                ),
              ),
            ],
          );
        }

        final sections = <Widget>[
          ...header,
          const SizedBox(key: ValueKey('spacer-header'), height: AppSpacing.lg),
          for (final slot in day.activeSlots) ...[
            Padding(
              key: ValueKey('slot-header-${slot.name}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(slot.labelAr,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppPalette.emerald)),
            ),
            for (final entry in day.entriesForSlot(slot)) ...[
              _EntryTile(
                  key: ValueKey('entry-${entry.entryId}'),
                  controller: controller,
                  entry: entry),
              SizedBox(
                  key: ValueKey('spacer-entry-${entry.entryId}'),
                  height: AppSpacing.sm),
            ],
            SizedBox(
                key: ValueKey('spacer-slot-${slot.name}'),
                height: AppSpacing.xs),
          ],
        ];

        // `ListView.builder` otherwise reuses each Element purely by its
        // *position* in the list across rebuilds. Entries, slot headers, and
        // spacers are all flattened into this one list, so removing or
        // toggling one entry shifts every later item's index -- without a
        // key-based lookup, Flutter can hand a `Dismissible` a *different*
        // entry's data mid-animation, which throws "A dismissed Dismissible
        // widget is still part of the tree." `findChildIndexCallback` plus
        // giving every item above a stable key (role-based for the fixed
        // header pieces, entry-id-based for anything that can move) is what
        // makes each item's identity survive the list changing shape instead
        // of just its slot.
        final keyToIndex = <Key, int>{
          for (var i = 0; i < sections.length; i++)
            if (sections[i].key != null) sections[i].key!: i,
        };

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(22, 66, 22, 130),
          itemCount: sections.length,
          findChildIndexCallback: (key) => keyToIndex[key],
          itemBuilder: (context, i) => StaggeredEntry(
            key: sections[i].key,
            index: i,
            maxStaggered: 8,
            child: sections[i],
          ),
        );
      });
}

class _Greeting extends StatelessWidget {
  final DateTime date;
  const _Greeting({super.key, required this.date});

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
  const _WeekStrip({super.key, required this.controller});

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

  const _EntryTile({super.key, required this.controller, required this.entry});

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

/// BMR and today's target, in plain numbers -- the ring shows progress, this
/// shows what it's progress *toward* and where that number came from.
class _TargetSummary extends StatelessWidget {
  final TodayController controller;
  const _TargetSummary({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final bmr = controller.bmr;
    final target = controller.targetKcal;
    if (bmr == null && target <= 0) return const SizedBox.shrink();

    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              label: 'الأيض الأساسي (BMR)',
              value: bmr == null ? '—' : '${bmr.round()}',
              unit: 'سعرة',
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: .12),
          ),
          Expanded(
            child: _StatColumn(
              label: 'الهدف اليومي',
              value: target <= 0 ? '—' : '${target.round()}',
              unit: 'سعرة',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatColumn({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppPalette.muted)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.text)),
              const SizedBox(width: 4),
              Text(unit,
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted)),
            ],
          ),
        ],
      );
}

/// What each ring color means -- floats over the top-right of the calorie
/// ring rather than living in a caption underneath, so it reads at a glance
/// without competing with the big kcal number for space.
class _RingLegend extends StatelessWidget {
  const _RingLegend();

  static const _entries = [
    (label: 'السعرات', color: null), // gradient swatch, not a flat color
    (label: 'بروتين', color: AppPalette.emerald),
    (label: 'كارب', color: AppPalette.amber),
    (label: 'دهون', color: AppPalette.violet),
  ];

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in _entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendSwatch(color: entry.color),
                    const SizedBox(width: 6),
                    Text(entry.label,
                        style: const TextStyle(
                            fontSize: 11, color: AppPalette.muted)),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _LegendSwatch extends StatelessWidget {
  /// `null` renders the calorie ring's own sweep gradient instead of a flat
  /// color, so the swatch matches the ring exactly rather than picking one
  /// color out of a ring that deliberately has several.
  final Color? color;
  const _LegendSwatch({required this.color});

  static const _gradient = SweepGradient(colors: [
    AppPalette.emerald,
    AppPalette.mint,
    AppPalette.amber,
    AppPalette.violet,
    AppPalette.emerald,
  ]);

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          gradient: color == null ? _gradient : null,
        ),
      );
}
