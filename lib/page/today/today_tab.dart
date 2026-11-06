import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/day/day_log.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/error_state.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/food/food_photo.dart';
import '../../ui/motion/navigation.dart';
import '../../ui/theme/app_colors.dart';
import '../assistant/assistant_tab.dart';
import 'edit_entry_sheet.dart';
import 'quick_add_sheet.dart';
import 'today_controller.dart';
import 'today_summary.dart';

class TodayTab extends GetView<TodayController> {
  const TodayTab({super.key});

  void _add(BuildContext context) {
    controller.ensureCurrentDay();
    if (controller.canEditSelectedDay) QuickAddSheet.show(context, controller);
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final day = controller.day.value;
        final date = controller.selectedDate.value;
        final readOnly =
            !controller.isViewingToday && !controller.editingPast.value;
        final loading = controller.loading.value;
        final error = controller.error.value;
        final sections = <Widget>[
          _TodayHeader(controller: controller),
          const SizedBox(height: 9),
          _WeekStrip(controller: controller),
          const SizedBox(height: 12),
          if (loading && day == null)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()))
          else if (error != null && day == null)
            ErrorState(message: error, onRetry: controller.retry)
          else if (day == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: AppStrings.noDayRecord,
                  message: AppStrings.emptyDay),
            )
          else ...[
            TodaySummary(
                key: ValueKey('summary-${day.dateKey}'),
                day: day,
                showPlannedDetails: false),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: Text(AppStrings.todayMeals,
                      style: Theme.of(context).textTheme.titleLarge)),
              OutlinedButton.icon(
                onPressed: readOnly ? null : () => _add(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(AppStrings.addMeal),
              ),
            ]),
            if (day.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: AppStrings.noMealsToday,
                    message: AppStrings.startWithMeal),
              ),
            for (final slot in day.activeSlots) ...[
              for (final entry in day.entriesForSlot(slot))
                Padding(
                  key: ValueKey('entry-${entry.entryId}'),
                  padding: const EdgeInsets.only(top: 10),
                  child: TodayEntryCard(
                    entry: entry,
                    readOnly: readOnly,
                    onToggle: () => controller.toggleEaten(entry.entryId),
                    onEdit: () => EditEntrySheet.show(context,
                        entry: entry,
                        onSave: (items) =>
                            controller.updateEntryItems(entry.entryId, items)),
                    onDelete: () => controller.deleteEntry(entry.entryId),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            _AssistantEntry(),
            TodayPlannedDetails(day: day),
          ],
        ];
        final indexes = <Key, int>{
          for (var i = 0; i < sections.length; i++)
            if (sections[i].key != null) sections[i].key!: i,
        };
        return ListView.builder(
          key: PageStorageKey('today-${DayLog.keyFor(date)}'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: sections.length,
          findChildIndexCallback: (key) => indexes[key],
          itemBuilder: (context, index) => sections[index],
        );
      });
}

class _TodayHeader extends StatelessWidget {
  final TodayController controller;
  const _TodayHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedDate.value;
    final today = controller.today.value;
    final available = controller.loggedDayKeys.value
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList()
      ..add(today)
      ..sort();
    final previous =
        available.where((date) => date.isBefore(selected)).lastOrNull;
    final next = available.where((date) => date.isAfter(selected)).firstOrNull;
    return Column(children: [
      SizedBox(
        height: 44,
        child: Stack(children: [
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(AppStrings.appName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppPalette.emerald,
                      fontWeight: FontWeight.w800,
                      fontSize: 23)),
              const SizedBox(width: 5),
              const Icon(Icons.eco_rounded,
                  color: AppPalette.emerald, size: 22),
            ]),
          ),
          PositionedDirectional(
            end: 0,
            child: IconButton(
              tooltip: AppStrings.askAssistant,
              onPressed: () => pushHealthak(() => const AssistantTab()),
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppPalette.emerald, size: 21),
            ),
          ),
        ]),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          tooltip: AppStrings.previousLoggedDay,
          onPressed:
              previous == null ? null : () => controller.selectDate(previous),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        Text(
          controller.isViewingToday
              ? AppStrings.today
              : '${AppStrings.weekdays[selected.weekday - 1]} ${selected.day}/${selected.month}',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppPalette.text, fontWeight: FontWeight.w800),
        ),
        IconButton(
          tooltip: AppStrings.nextLoggedDay,
          onPressed: next == null ? null : () => controller.selectDate(next),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ]),
      if (!controller.isViewingToday)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () => controller.selectDate(today),
            child: const Text(AppStrings.backToToday),
          ),
          TextButton.icon(
            onPressed: controller.toggleEditingPast,
            icon: Icon(
                controller.editingPast.value
                    ? Icons.lock_open_outlined
                    : Icons.edit_outlined,
                size: 17),
            label: Text(controller.editingPast.value
                ? AppStrings.done
                : AppStrings.edit),
          ),
        ]),
    ]);
  }
}

class _AssistantEntry extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Material(
        color: AppPalette.emerald,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const ValueKey('today-assistant'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => pushHealthak(() => const AssistantTab()),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(children: [
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.askAssistant,
                      style: TextStyle(
                          color: AppPalette.onAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  SizedBox(height: 1),
                  Text(AppStrings.assistantEntryHint,
                      style:
                          TextStyle(color: AppPalette.onAccent, fontSize: 11)),
                ],
              )),
              SizedBox(width: 10),
              CircleAvatar(
                radius: 23,
                backgroundColor: Color(0x2EFFFFFF),
                child: Icon(Icons.chat_bubble_outline_rounded,
                    color: AppPalette.onAccent, size: 23),
              ),
            ]),
          ),
        ),
      );
}

class _WeekStrip extends StatelessWidget {
  final TodayController controller;
  const _WeekStrip({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() {
        final today = controller.today.value;
        final selected = controller.selectedDate.value;
        final monday = selected.subtract(Duration(days: selected.weekday - 1));
        final logged = controller.loggedDayKeys.value;
        final days = [
          for (var i = 0; i < 7; i++) monday.add(Duration(days: i))
        ];
        return LayoutBuilder(builder: (context, constraints) {
          const gap = 3.0;
          final chipWidth = (constraints.maxWidth - gap * 6) / 7;
          return Row(children: [
            for (var i = 0; i < days.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              DayChip(
                date: days[i],
                width: chipWidth,
                selected: DayLog.keyFor(days[i]) == DayLog.keyFor(selected),
                onTap: DayLog.keyFor(days[i]) == DayLog.keyFor(today) ||
                        DayLog.keyFor(days[i]) == DayLog.keyFor(selected) ||
                        logged.contains(DayLog.keyFor(days[i]))
                    ? () => controller.selectDate(days[i])
                    : null,
              ),
            ],
          ]);
        });
      });
}

class DayChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback? onTap;
  final double width;
  static const stripWidth = 44.0;

  const DayChip(
      {required this.date,
      required this.selected,
      super.key,
      this.onTap,
      this.width = stripWidth});

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        enabled: onTap != null,
        label:
            '${AppStrings.weekdays[date.weekday - 1]} ${date.day}/${date.month}',
        child: Material(
          color: selected ? AppPalette.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: width,
              constraints: const BoxConstraints(minHeight: 53),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 1),
              child: Column(children: [
                Text(AppStrings.weekdayShort[date.weekday - 1],
                    style: TextStyle(
                        fontSize: 9,
                        color:
                            selected ? AppPalette.onAccent : AppPalette.muted)),
                const SizedBox(height: 2),
                Text('${date.day}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppPalette.onAccent
                            : onTap == null
                                ? AppPalette.muted.withValues(alpha: .5)
                                : AppPalette.text)),
              ]),
            ),
          ),
        ),
      );
}

/// Explicit edit and delete controls complement gestures, so keyboard and
/// accessibility users can perform every action without discovering a swipe.
class TodayEntryCard extends StatelessWidget {
  final DayEntry entry;
  final bool readOnly;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TodayEntryCard(
      {required this.entry,
      required this.readOnly,
      required this.onToggle,
      required this.onEdit,
      required this.onDelete,
      super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteDayEntryTitle),
        content: const Text(AppStrings.deleteDayEntryBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.assistantCancel)),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.delete)),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(9),
        borderRadius: BorderRadius.circular(17),
        onLongPress: readOnly ? null : onEdit,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          FoodPhoto(
            asset: FoodPhoto.forMeal(
                entry.name, entry.items.map((item) => item.name)),
            size: 74,
            fallbackIcon: switch (entry.slot) {
              MealSlot.breakfast => Icons.breakfast_dining_outlined,
              MealSlot.lunch => Icons.rice_bowl_outlined,
              MealSlot.dinner => Icons.dinner_dining_outlined,
              MealSlot.snack => Icons.local_cafe_outlined,
            },
          ),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(entry.slot.labelAr,
                  style:
                      const TextStyle(fontSize: 10, color: AppPalette.emerald)),
              Text(
                entry.items
                    .map((item) =>
                        '${item.name} ${item.grams.round()} ${AppStrings.grams}')
                    .join('، '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppPalette.muted),
              ),
              Text(
                AppStrings.entryNutrition(
                    entry.kcal.round(), entry.totals.protein.round()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppPalette.emerald,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),
          SizedBox(
            width: 46,
            child: Column(children: [
              if (!readOnly)
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Checkbox(
                    value: entry.eaten,
                    semanticLabel: AppStrings.eatenLabel(entry.name),
                    shape: const CircleBorder(),
                    onChanged: (_) => onToggle(),
                  ),
                )
              else
                Icon(entry.eaten ? Icons.check_circle : Icons.lock_outline,
                    color: AppPalette.muted, size: 21),
              if (!readOnly)
                PopupMenuButton<String>(
                  tooltip: AppStrings.mealActions,
                  icon: const Icon(Icons.more_horiz,
                      size: 19, color: AppPalette.muted),
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : _confirmDelete(context),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text(AppStrings.edit)),
                    PopupMenuItem(
                        value: 'delete', child: Text(AppStrings.delete)),
                  ],
                ),
            ]),
          ),
        ]),
      );
}
