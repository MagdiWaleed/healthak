import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/day/day_log.dart';
import '../../ui/components/calorie_ring.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/error_state.dart';
import '../../ui/components/macro_numbers_panel.dart';
import '../../ui/feedback/haptics.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/stacking_card.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/motion/celebration.dart';
import '../../ui/motion/eat_toggle/eat_check.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/glass_tokens.dart';
import '../../ui/theme/mood_palette.dart';
import '../../ui/theme/motion_settings.dart';
import '../home/home_controller.dart';
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
  late final TodayController controller = Get.find<TodayController>();
  Worker? _tabWorker;

  @override
  void initState() {
    super.initState();
    // The tab lives in an IndexedStack, so becoming visible is not a rebuild.
    // Watch the shell's tab index and replay the arrival sweep each time Today
    // is entered; fire once now for the first mount.
    final home = Get.find<HomeController>();
    _tabWorker = ever(home.tabIndex, (int index) {
      if (index == 0) controller.replayArrival();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.replayArrival();
    });
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
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
                // Re-sweeps only on tab arrival, never on an eat-toggle.
                arrivalTrigger: controller.arrivalPulse.value,
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
      const SizedBox(
          key: ValueKey('spacer-macro-progress'), height: AppSpacing.md),
      MacroNumbersPanel(
        key: const ValueKey('macro-progress'),
        consumed: day.consumedTotals,
        target: day.targets.macros,
        planned: day.plannedTotals,
        arrivalTrigger: controller.arrivalPulse.value,
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
        // A PageStorageKey (not a plain ValueKey): the eat-toggle reassigns
        // `day.value`, which rebuilds this whole subtree through the parent
        // Obx + AnimatedSwitcher. Without the offset being parked in
        // PageStorage, that rebuild dropped the scroll position back to the
        // top every time a row was ticked.
        key: PageStorageKey<String>('day-blank-$dateKey'),
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

    var specularIndex = 0;
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
          StackingCard(
            key: ValueKey('entry-${entry.entryId}'),
            // The collapsed ring header is 108 tall and the viewport runs
            // edge to edge from the top of the screen, so this is the line
            // where a row disappears under it.
            stackTop: _TodayRingHeaderDelegate.collapsedExtent + 8,
            child: _EntryTile(
              controller: controller,
              entry: entry,
              readOnly: readOnly,
              specularAngleOffset:
                  specularIndex++ * GlassTokens.listSpecularStepDeg,
            ),
          ),
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
      // PageStorageKey so the scroll offset survives the parent Obx +
      // AnimatedSwitcher rebuild that every eat-toggle triggers (it reassigns
      // `day.value`). A plain ValueKey let it snap back to the top.
      key: PageStorageKey<String>('day-$dateKey'),
      // Parked rows are painted from a layout position above the viewport;
      // without this the deepest of them get recycled out from under the pile.
      cacheExtent: kStackingCacheExtent,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _TodayRingHeaderDelegate(
            day: day,
            controller: controller,
            ringAccent: ringAccent,
            goalTrigger: controller.goalCelebration.value,
            rippleTrigger: controller.eatPulse.value,
            arrivalTrigger: controller.arrivalPulse.value,
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

  /// Replays the ring's and macro panel's from-zero fill sweep; bumped on tab
  /// arrival only, never on an eat-toggle.
  final int arrivalTrigger;

  _TodayRingHeaderDelegate({
    required this.day,
    required this.controller,
    required this.ringAccent,
    required this.goalTrigger,
    required this.rippleTrigger,
    required this.arrivalTrigger,
  });

  /// Also the line the entry rows pile up against -- see [StackingCard].
  static const double collapsedExtent = 108;

  /// Where the macro panel sits with the header fully open.
  ///
  /// The ring's box is 200 tall from [_ringTop], but it paints a soft glow
  /// well past that, so butting the panel straight up against 378 read as the
  /// two cards touching. This is that edge plus a real gap.
  static const double _ringTop = 178;
  static const double _panelTop = _ringTop + 200 + 40;

  /// The compact bar's geometry: the ring's collapsed diameter, the screen
  /// margin the bar sits inside, and how far the macro panel is scaled down.
  /// Deliberately not centred on the ring. A perfectly symmetric bar left the
  /// whole leading corner empty -- the day is a square, so it cannot both
  /// reach the margin and stay square beside a centred ring. Seating the day
  /// near the leading margin and letting the ring sit just off centre fills
  /// the width instead.
  static const double _ringCollapsed = 88;
  static const double _dayCollapsed = 72;
  static const double _barLeading = 20;
  static const double _barMargin = 8;
  static const double _panelCollapsedScale = .62;

  @override
  double get minExtent => collapsedExtent;

  // Grown with `_panelTop`: the target summary is anchored to the bottom of
  // this box, so pushing the macro panel down without this just trades one
  // overlap for another.
  @override
  double get maxExtent => 690;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    // The rearrangement is front-loaded, the fades are not. Run linearly, the
    // ring is still half-size and near the middle while the panel is still
    // wide, and the two spend most of the travel overlapping; easing the
    // geometry gets both into their compact places early and then simply
    // holds them there.
    final c = Curves.easeOutCubic.transform(t);
    final ringSize = lerpDouble(200, _ringCollapsed, c)!;
    final detailOpacity = (1 - (t / .55)).clamp(0.0, 1.0);
    final ringTop = lerpDouble(_ringTop, 6, c)!;
    // The ring stays centred at every point of the collapse -- it is the
    // headline, and the compact bar is built around it: the day on one side,
    // the macros on the other.
    //
    // The selected day rides out of the week strip into that bar as the strip
    // itself fades, so the date stays on screen while scrolling instead of
    // vanishing with the rest of the header detail.
    // Grows from a strip chip into a square the size of the ring, and lands
    // on the same top edge, so the three pieces of the compact bar sit on one
    // line at one height.
    final dayTop = lerpDouble(100, 6, c)!;
    final dayWidth = lerpDouble(DayChip.stripWidth, _dayCollapsed, c)!;
    final dayHeight = lerpDouble(64, _dayCollapsed, c)!;
    final dayOpacity = 1 - detailOpacity;
    // The panel narrows in layout *and* scales about its trailing (RTL:
    // right) edge, so it compresses in both dimensions and ends up beside the
    // ring instead of under it. Two mechanisms rather than one because the
    // scale alone left the panel's leading edge over the ring for most of the
    // travel, and narrowing alone cannot shrink its height.
    // Laid out wider than it ends up looking, then scaled down: giving it a
    // 127px-wide box directly would reflow three labelled rows into something
    // unreadable, while laying out at 231 and scaling to .55 keeps the
    // proportions it has when open.
    final panelScale = lerpDouble(1, _panelCollapsedScale, c)!;
    final panelRight = lerpDouble(12, _barMargin, c)!;
    final panelTop = lerpDouble(_panelTop, 6, c)!;

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
      // The compact bar's three pieces butt up against each other, which
      // means knowing the width they are being laid out in. `LayoutBuilder`
      // rather than `MediaQuery`, so the numbers come from the box this
      // header actually got.
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        // The bar packs from the leading edge -- day, ring, then the panel
        // taking whatever is left -- rather than centring on the ring.
        const ringLeftCollapsed = _barLeading + _dayCollapsed;
        const ringRightCollapsed = ringLeftCollapsed + _ringCollapsed;
        final dayLeft =
            lerpDouble((w - DayChip.stripWidth) / 2, _barLeading, c)!;
        // Centred while the header is open, drifting just left of centre as
        // it collapses.
        final ringLeft = lerpDouble((w - ringSize) / 2, ringLeftCollapsed, c)!;
        // The panel is scaled about its trailing edge, so its *visual* left
        // is `right - scale * layoutWidth`. Solving that for the layout box
        // is what makes the shrunken panel land exactly on the ring's edge
        // instead of near it.
        final panelVisual = (w - _barMargin) - ringRightCollapsed;
        final panelLeft = lerpDouble(
          22,
          w - _barMargin - panelVisual / _panelCollapsedScale,
          c,
        )!;
        // Every child carries a stable key. This Stack has a conditional
        // child (the day chip), and Flutter matches keyless Stack children by
        // position -- so the moment a scroll made the chip appear, the ring
        // and macro panel shifted one slot, their elements were torn down and
        // rebuilt, and their fresh State replayed the arrival fill sweep on
        // every scroll. Keys pin each element to its identity instead.
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            PositionedDirectional(
              key: const ValueKey('hdr-greeting'),
              start: 22,
              top: 14,
              child: Opacity(
                opacity: detailOpacity,
                child: _Greeting(controller: controller),
              ),
            ),
            Positioned(
              key: const ValueKey('hdr-weekstrip'),
              top: 100,
              left: 22,
              right: 22,
              child: Opacity(
                opacity: detailOpacity,
                child: _WeekStrip(controller: controller),
              ),
            ),
            if (dayOpacity > 0)
              Positioned(
                key: const ValueKey('hdr-daychip'),
                top: dayTop,
                left: dayLeft,
                width: dayWidth,
                height: dayHeight,
                child: Opacity(
                  opacity: dayOpacity,
                  child: DayChip(
                    date: controller.selectedDate.value,
                    selected: true,
                    width: dayWidth,
                  ),
                ),
              ),
            Positioned(
              key: const ValueKey('hdr-ring'),
              top: ringTop,
              left: ringLeft,
              width: ringSize,
              height: ringSize,
              // `GoalCelebration` paints a fixed 320px burst, so left to
              // itself it would force this box 320 wide and the ring would
              // never land where it was put. Sizing it to the ring and
              // letting the burst overflow is what keeps the placement
              // honest.
              child: SizedBox.square(
                dimension: ringSize,
                child: OverflowBox(
                  maxWidth: 320,
                  maxHeight: 320,
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
                      arrivalTrigger: arrivalTrigger,
                      animateFromZero: false,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              key: const ValueKey('hdr-legend'),
              top: _ringTop,
              right: 8,
              child: Opacity(
                opacity: detailOpacity,
                child: const _RingLegend(),
              ),
            ),
            Positioned(
              key: const ValueKey('hdr-panel'),
              left: panelLeft,
              right: panelRight,
              top: panelTop,
              child: Transform.scale(
                scale: panelScale,
                alignment: Alignment.topRight,
                child: MacroNumbersPanel(
                  consumed: day.consumedTotals,
                  target: day.targets.macros,
                  planned: day.plannedTotals,
                  arrivalTrigger: arrivalTrigger,
                ),
              ),
            ),
            Positioned(
              key: const ValueKey('hdr-target'),
              left: 22,
              right: 22,
              bottom: 16,
              child: Opacity(
                opacity: detailOpacity,
                child: _TargetSummary(controller: controller),
              ),
            ),
          ],
        );
      }),
    );
  }

  @override
  bool shouldRebuild(covariant _TodayRingHeaderDelegate oldDelegate) =>
      oldDelegate.day != day ||
      oldDelegate.ringAccent != ringAccent ||
      oldDelegate.goalTrigger != goalTrigger ||
      oldDelegate.rippleTrigger != rippleTrigger ||
      oldDelegate.arrivalTrigger != arrivalTrigger ||
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
        final logged = controller.loggedDayKeys.value;
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
        // Centred, not start-aligned. Now that empty days are filtered out
        // the strip is usually two or three chips wide, and a short row
        // pinned to the leading edge read as a list that had lost its other
        // items. `minWidth` on the row is what centres it when it fits and
        // still lets a full seven-day week scroll.
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (i, date) in days.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    DayChip(
                      date: date,
                      selected: _sameDay(date, selected),
                      onTap: () => controller.selectDate(date),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// One day in the week strip -- and, once the header collapses, the single
/// selected day that rides up into the compact bar. Shared so the travelling
/// copy is literally the same chip rather than a lookalike that would drift
/// out of sync with the strip's styling.
class DayChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback? onTap;

  /// Defaults to the strip's chip width. The collapsed header passes the
  /// ring's diameter instead, so the day reads as a square the same size as
  /// the circle beside it.
  final double width;

  static const double stripWidth = 44;

  const DayChip({
    required this.date,
    required this.selected,
    super.key,
    this.onTap,
    this.width = stripWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Type scales with the chip so the big square is not a small chip with a
    // lot of empty space in it.
    // Capped well below the width ratio: at full ratio the square reads as
    // two oversized glyphs and overpowers the ring beside it.
    final scale = (width / stripWidth).clamp(1.0, 1.35);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.emerald.withValues(alpha: .22)
              : Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14 * scale),
          border: selected
              ? Border.all(color: AppPalette.emerald.withValues(alpha: .5))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_weekdayLabels[date.weekday - 1],
                style: TextStyle(
                    fontSize: 11 * scale,
                    color: selected ? AppPalette.emerald : AppPalette.muted)),
            SizedBox(height: 2 * scale),
            Text('${date.day}',
                style: TextStyle(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppPalette.text : AppPalette.muted)),
          ],
        ),
      ),
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
  final double specularAngleOffset;

  // No `key`: the list's stable key now lives on the `StackingCard` that
  // wraps this, which is the widget the sliver actually recycles.
  const _EntryTile({
    required this.controller,
    required this.entry,
    required this.readOnly,
    required this.specularAngleOffset,
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
          specularAngleOffset: specularAngleOffset,
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
          PositionedDirectional(
            start: 0,
            end: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: struck ? 1 : 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, factor, _) => FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: factor,
                child: Container(height: 1.4, color: AppPalette.muted),
              ),
            ),
          ),
        ],
      );
}

/// Maintenance calories and today's target, in plain numbers -- the ring shows
/// progress, while this shows the baseline before the user's goal adjustment.
class _TargetSummary extends StatelessWidget {
  final TodayController controller;
  const _TargetSummary({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final baseCalories = controller.baseCalories;
    final target = controller.targetKcal;
    if (baseCalories == null && target <= 0) return const SizedBox.shrink();

    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              label: 'سعرات الثبات (TDEE)',
              value: baseCalories == null ? '—' : '${baseCalories.round()}',
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
