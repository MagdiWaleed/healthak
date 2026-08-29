import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/day/day_log.dart';
import '../../service/auth_service.dart';
import '../../ui/components/calorie_ring.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/error_state.dart';
import '../../ui/components/macro_numbers_panel.dart';
import '../../ui/feedback/haptics.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/motion/celebration.dart';
import '../../ui/motion/eat_toggle/eat_check.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/mood_palette.dart';
import '../../ui/theme/motion_settings.dart';
import 'edit_entry_sheet.dart';
import 'quick_add_sheet.dart';
import 'today_controller.dart';

const _weekdayLabels = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
  late final TodayController controller = Get.isRegistered<TodayController>()
      ? Get.find<TodayController>()
      : Get.put(TodayController(uid: Get.find<AuthService>().currentUser!.uid));

  @override
  void dispose() {
    Get.delete<TodayController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        // `_dayView` is invoked synchronously inside this closure, so every
        // `.value` it reads still registers as a dependency of *this* Obx.
        final child = _dayView(context);
        return AnimatedSwitcher(
          duration: MotionSettings.duration(
              context, const Duration(milliseconds: 240)),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          // The default layout builder centres the outgoing child and sizes
          // the stack to the incoming one, which collapses a full-height
          // scroll view to nothing mid-transition. Both days are full-bleed
          // here, so they simply overlap.
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, if (current != null) current],
          ),
          child: child,
        );
      });

  /// One day's screen, keyed by which day it is. The key is what turns a
  /// date change into a cross-fade while an eat-toggle on the *same* day
  /// stays an in-place rebuild.
  Widget _dayView(BuildContext context) {
    final dateKey = DayLog.keyFor(controller.selectedDate.value);
    if (controller.loading.value && controller.day.value == null) {
      return const Center(
        key: ValueKey('day-loading'),
        child: CircularProgressIndicator(),
      );
    }
    final error = controller.error.value;
    if (error != null && controller.day.value == null) {
      return ErrorState(
          key: const ValueKey('day-error'),
          message: error,
          onRetry: controller.retry);
    }
    final day = controller.day.value;
    final ringAccent = MoodPalette.forMood(controller.mood.value).ringAccent;
    if (day == null) {
      // Loading has finished (the branch above already returned otherwise)
      // and there is no error, so this is a real, valid state: a past day
      // that was never opened has no document at all -- watch() correctly
      // emits null rather than materializing one. Only `ensureDay` (today
      // only) creates a document; browsing history must never invent one.
      // A bare `CircularProgressIndicator` here would spin forever with
      // no way out.
      return Center(
        key: ValueKey('day-missing-$dateKey'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Greeting(controller: controller),
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
      _Greeting(key: const ValueKey('greeting'), controller: controller),
      const SizedBox(key: ValueKey('spacer-greeting'), height: AppSpacing.md),
      _WeekStrip(key: const ValueKey('weekstrip'), controller: controller),
      const SizedBox(key: ValueKey('spacer-weekstrip'), height: AppSpacing.lg),
      Stack(
        key: const ValueKey('ring'),
        alignment: Alignment.topCenter,
        children: [
          Center(
            child: GoalCelebration(
              trigger: controller.goalCelebration.value,
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
                ringAccent: ringAccent,
                rippleTrigger: controller.eatPulse.value,
                // A ring rebuilt on every eat-toggle shouldn't re-sweep from
                // zero every time -- only the very first render does.
                animateFromZero: false,
              ),
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
      _TargetSummary(
          key: const ValueKey('target-summary'), controller: controller),
      const SizedBox(key: ValueKey('spacer-macro-progress'), height: AppSpacing.md),
      MacroNumbersPanel(
        key: const ValueKey('macro-progress'),
        consumed: day.consumedTotals,
        target: day.targets.macros,
        planned: day.plannedTotals,
        animationTrigger: controller.eatPulse.value,
      ),
    ];

    // A `ListView` top-aligns short content, and the FAB is docked at a
    // fixed position near the bottom of the *viewport* regardless of how
    // much content exists -- on a day with no entries the two collided
    // (the CTA below rendered directly under the FAB). `SliverFillRemaining`
    // centers short content in the true remaining viewport instead, and
    // the populated branch still scrolls normally past it.
    if (day.isEmpty) {
      return CustomScrollView(
        key: ValueKey('day-blank-$dateKey'),
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
                      onPressed: controller.canEditSelectedDay
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

    // Read here, inside the Obx closure, and passed down. `_EntryTile`'s
    // own `build` runs outside this closure, so reading either value
    // there would not register as a dependency and toggling the unlock
    // would change nothing on screen.
    final readOnly =
        !controller.isViewingToday && !controller.editingPast.value;

    final sections = <Widget>[
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
              entry: entry,
              readOnly: readOnly),
          SizedBox(
              key: ValueKey('spacer-entry-${entry.entryId}'),
              height: AppSpacing.sm),
        ],
        SizedBox(
            key: ValueKey('spacer-slot-${slot.name}'), height: AppSpacing.xs),
      ],
    ];

    // `SliverList` otherwise reuses each Element purely by its
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

    return CustomScrollView(
      key: ValueKey('day-$dateKey'),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _TodayRingHeaderDelegate(
            day: day,
            controller: controller,
            ringAccent: ringAccent,
            goalTrigger: controller.goalCelebration.value,
            rippleTrigger: controller.eatPulse.value,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 130),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => StaggeredEntry(
                key: sections[i].key,
                index: i,
                maxStaggered: 8,
                child: sections[i],
              ),
              childCount: sections.length,
              findChildIndexCallback: (key) => keyToIndex[key],
            ),
          ),
        ),
      ],
    );
  }
}

/// The caloric headline is deliberately a pinned sliver rather than a widget
/// listening to scroll pixels. The render pipeline supplies [shrinkOffset],
/// keeping the big-to-compact transition cheap and leaving zero per-frame
/// controller work in TodayController.
class _TodayRingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DayLog day;
  final TodayController controller;
  final Color ringAccent;
  final int goalTrigger;
  final int rippleTrigger;

  _TodayRingHeaderDelegate({
    required this.day,
    required this.controller,
    required this.ringAccent,
    required this.goalTrigger,
    required this.rippleTrigger,
  });

  @override
  double get minExtent => 108;

  @override
  double get maxExtent => 650;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final ringSize = lerpDouble(200, 96, t)!;
    final detailOpacity = (1 - (t / .55)).clamp(0.0, 1.0);
    final ringTop = lerpDouble(178, 6, t)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppPalette.ink.withValues(alpha: .90),
            AppPalette.ink.withValues(alpha: .74),
            AppPalette.ink.withValues(alpha: 0),
          ],
          stops: const [0, .70, 1],
        ),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          PositionedDirectional(
            start: 22,
            top: 14,
            child: Opacity(
              opacity: detailOpacity,
              child: _Greeting(controller: controller),
            ),
          ),
          Positioned(
            top: 100,
            left: 22,
            right: 22,
            child: Opacity(
              opacity: detailOpacity,
              child: _WeekStrip(controller: controller),
            ),
          ),
          Positioned(
            top: ringTop,
            child: GoalCelebration(
              trigger: goalTrigger,
              child: CalorieRing(
                consumed: day.consumedKcal,
                target: day.targets.kcal,
                size: ringSize,
                consumedMacros: day.consumedTotals,
                targetMacros: day.targets.macros,
                plannedKcal: day.plannedKcal,
                plannedMacros: day.plannedTotals,
                ringAccent: ringAccent,
                rippleTrigger: rippleTrigger,
                animateFromZero: false,
              ),
            ),
          ),
          Positioned(
            top: 178,
            right: 8,
            child: Opacity(
              opacity: detailOpacity,
              child: const _RingLegend(),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 398,
            child: Opacity(
              opacity: detailOpacity,
              child: MacroNumbersPanel(
                consumed: day.consumedTotals,
                target: day.targets.macros,
                planned: day.plannedTotals,
                animationTrigger: rippleTrigger,
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 16,
            child: Opacity(
              opacity: detailOpacity,
              child: _TargetSummary(controller: controller),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TodayRingHeaderDelegate oldDelegate) =>
      oldDelegate.day != day ||
      oldDelegate.ringAccent != ringAccent ||
      oldDelegate.goalTrigger != goalTrigger ||
      oldDelegate.rippleTrigger != rippleTrigger ||
      oldDelegate.controller.selectedDate.value !=
          controller.selectedDate.value;
}

class _Greeting extends StatelessWidget {
  final TodayController controller;
  const _Greeting({super.key, required this.controller});

  String _greeting(DateTime date, bool isToday) {
    if (!isToday) return _weekdayFullNames[date.weekday - 1];
    final hour = DateTime.now().hour;
    return hour < 18 ? 'صباح الخير' : 'مساء الخير';
  }

  // Its own `Obx`, deliberately. This widget's `build` runs outside the
  // closure of whichever `Obx` created it, so reading `selectedDate`/`today`
  // here would not register as a dependency of that one -- the greeting would
  // simply stop tracking the date it names.
  @override
  Widget build(BuildContext context) => Obx(() {
        final date = controller.selectedDate.value;
        final isToday = controller.isViewingToday;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting(date, isToday),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            if (isToday)
              Text('خطتك الغذائية واضحة أمامك',
                  style: Theme.of(context).textTheme.bodyLarge)
            else
              // The only "browsing history" state that has no week strip on
              // screen at all is the empty-day branch, which carries its own
              // explicit button; everywhere else this doubles as the quiet way
              // back so the user is never stuck relying on spotting today's
              // cell in the strip.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => controller.selectDate(DateTime.now()),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'استعراض يوم سابق',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppPalette.emerald,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppPalette.emerald,
                                  ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.today_rounded,
                            size: 16, color: AppPalette.emerald),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Correcting history has to be deliberate, so it is a
                  // second, explicitly-labelled action rather than the rows
                  // simply being live: the day stays locked and green until
                  // this is pressed.
                  _EditDayToggle(controller: controller),
                ],
              ),
          ],
        );
      });
}

/// Unlocks the browsed day for correction, and says which state it is in.
class _EditDayToggle extends StatelessWidget {
  final TodayController controller;

  const _EditDayToggle({required this.controller});

  // Its own `Obx`. This sits inside the pinned `SliverPersistentHeader`,
  // whose `shouldRebuild` compares the day and the selected date -- not the
  // unlock -- so without this the rows would go editable while the button
  // still read "تعديل".
  @override
  Widget build(BuildContext context) => Obx(() {
        final editing = controller.editingPast.value;
        return GestureDetector(
          onTap: controller.toggleEditingPast,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: editing
                  ? AppPalette.emerald.withValues(alpha: .22)
                  : Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: editing
                    ? AppPalette.emerald.withValues(alpha: .55)
                    : Colors.white.withValues(alpha: .16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(editing ? Icons.lock_open_rounded : Icons.edit_outlined,
                    size: 13,
                    color: editing ? AppPalette.emerald : AppPalette.muted),
                const SizedBox(width: 4),
                Text(
                  editing ? 'تم' : 'تعديل',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: editing ? AppPalette.emerald : AppPalette.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      });
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
    return SizedBox(
      height: 64,
      child: Obx(() {
        // Read from the controller's published date, never `DateTime.now()`.
        // Computed inline here, this whole strip froze at whatever day the
        // last rebuild happened on: after midnight the new day kept failing
        // the `isFuture` test and stayed permanently untappable.
        final now = controller.today.value;
        // Monday of the current week through Sunday. Browsing beyond this
        // range is what History (a full calendar) is for.
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final selected = controller.selectedDate.value;
        final logged = controller.loggedDayKeys;
        // Only days there is something to look at. A chip for an empty past
        // day, or for a future one, leads nowhere -- it either dead-ends on
        // "no record for this day" or is greyed out and untappable. Today
        // and the current selection are always kept so the strip can never
        // become a place with no way back.
        final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))]
            .where((date) {
          if (_sameDay(date, now) || _sameDay(date, selected)) return true;
          return logged.contains(DayLog.keyFor(date));
        }).toList();
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final date = days[i];
            final isSelected = _sameDay(date, selected);
            return GestureDetector(
              onTap: () => controller.selectDate(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppPalette.emerald.withValues(alpha: .22)
                      : Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(
                          color: AppPalette.emerald.withValues(alpha: .5))
                      : null,
                ),
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

  /// A past day is a frozen historical record, so browsing one must not let
  /// the swipe-delete, long-press editor, or eat toggle mutate it by
  /// accident. Computed by the caller inside its `Obx` -- see the note there
  /// -- and false again once that day is deliberately unlocked for
  /// correction.
  final bool readOnly;

  const _EntryTile({
    super.key,
    required this.controller,
    required this.entry,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(entry.entryId),
      direction: readOnly ? DismissDirection.none : DismissDirection.endToStart,
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
        onLongPress: readOnly
            ? null
            : () {
                unawaited(HapticPhrase.play(AppHaptics.lift));
                EditEntrySheet.show(
                  context,
                  entry: entry,
                  onSave: (items) =>
                      controller.updateEntryItems(entry.entryId, items),
                );
              },
        child: GlassCard(
          // The read-only treatment: a green-tinted glass body instead of a
          // checkbox that looks tappable but isn't -- the surface itself
          // says "locked", nothing pretending to be a control.
          tint: readOnly ? AppPalette.emerald : null,
          highlighted: readOnly,
          child: Row(
            children: [
              if (!readOnly) ...[
                EatCheck(
                  eaten: entry.eaten,
                  onToggle: () => controller.toggleEaten(entry.entryId),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
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

  const _StatColumn(
      {required this.label, required this.value, required this.unit});

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
                  style:
                      const TextStyle(fontSize: 11, color: AppPalette.muted)),
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
