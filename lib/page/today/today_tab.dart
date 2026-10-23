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
          const SizedBox(height: 18),
          _WeekStrip(controller: controller),
          const SizedBox(height: 18),
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
            TodaySummary(key: ValueKey('summary-${day.dateKey}'), day: day),
            const SizedBox(height: 14),
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
          ],
        ];
        final indexes = <Key, int>{
          for (var i = 0; i < sections.length; i++)
            if (sections[i].key != null) sections[i].key!: i,
        };
        return ListView.builder(
          key: PageStorageKey('today-${DayLog.keyFor(date)}'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.eco_outlined, color: AppPalette.emerald, size: 26),
            const SizedBox(width: 8),
            Text(AppStrings.appName,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppPalette.emerald)),
            const Spacer(),
            IconButton(
              tooltip: AppStrings.askAssistant,
              onPressed: () => pushHealthak(() => const AssistantTab()),
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppPalette.emerald),
            ),
            if (controller.isViewingToday)
              Text(AppStrings.today,
                  style: Theme.of(context).textTheme.titleMedium),
            if (!controller.isViewingToday)
              TextButton.icon(
                onPressed: () => controller.selectDate(controller.today.value),
                icon: const Icon(Icons.today_outlined, size: 18),
                label: const Text(AppStrings.backToToday),
              ),
          ]),
          const SizedBox(height: 6),
          if (!controller.isViewingToday)
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                  child: Text(
                      controller.isViewingToday
                          ? AppStrings.today
                          : AppStrings.dayRecord,
                      style: Theme.of(context).textTheme.headlineMedium)),
              if (!controller.isViewingToday)
                TextButton.icon(
                  onPressed: controller.toggleEditingPast,
                  icon: Icon(
                      controller.editingPast.value
                          ? Icons.lock_open_outlined
                          : Icons.edit_outlined,
                      size: 18),
                  label: Text(controller.editingPast.value
                      ? AppStrings.done
                      : AppStrings.edit),
                ),
            ]),
          if (!controller.isViewingToday)
            Text(AppStrings.historyReadOnly,
                style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
}

class _AssistantEntry extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Material(
        color: AppPalette.emerald,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('today-assistant'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => pushHealthak(() => const AssistantTab()),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  color: AppPalette.onAccent, size: 25),
              SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.askAssistant,
                      style: TextStyle(
                          color: AppPalette.onAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  SizedBox(height: 3),
                  Text(AppStrings.assistantEntryHint,
                      style:
                          TextStyle(color: AppPalette.onAccent, fontSize: 11)),
                ],
              )),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: AppPalette.onAccent),
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
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final logged = controller.loggedDayKeys.value;
        final days = [
          for (var i = 0; i < 7; i++) monday.add(Duration(days: i))
        ];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final date in days) ...[
              DayChip(
                date: date,
                selected: DayLog.keyFor(date) == DayLog.keyFor(selected),
                onTap: DayLog.keyFor(date) == DayLog.keyFor(today) ||
                        logged.contains(DayLog.keyFor(date))
                    ? () => controller.selectDate(date)
                    : null,
              ),
              const SizedBox(width: 6),
            ],
          ]),
        );
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
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: width,
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Column(children: [
                Text(AppStrings.weekdayShort[date.weekday - 1],
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            selected ? AppPalette.onAccent : AppPalette.muted)),
                const SizedBox(height: 4),
                Text('${date.day}',
                    style: TextStyle(
                        fontSize: 16,
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

  @override
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey(entry.entryId),
        direction:
            readOnly ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppPalette.danger.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.delete_outline, color: AppPalette.danger),
        ),
        onDismissed: (_) => onDelete(),
        child: GlassCard(
          padding: const EdgeInsets.all(10),
          onLongPress: readOnly ? null : onEdit,
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            FoodPhoto(
              asset: FoodPhoto.forMeal(
                  entry.name, entry.items.map((item) => item.name)),
              fallbackIcon: switch (entry.slot) {
                MealSlot.breakfast => Icons.breakfast_dining_outlined,
                MealSlot.lunch => Icons.rice_bowl_outlined,
                MealSlot.dinner => Icons.dinner_dining_outlined,
                MealSlot.snack => Icons.local_cafe_outlined,
              },
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(entry.slot.labelAr,
                      style: const TextStyle(
                          fontSize: 11, color: AppPalette.emerald)),
                  const SizedBox(height: 3),
                  Text(
                      entry.items
                          .map((item) =>
                              '${item.name} ${item.grams.round()} ${AppStrings.grams}')
                          .join('، '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppPalette.muted)),
                  const SizedBox(height: 5),
                  Text(
                      AppStrings.entryNutrition(
                          entry.kcal.round(), entry.totals.protein.round()),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.emerald,
                          fontWeight: FontWeight.w600)),
                ])),
            const SizedBox(width: 2),
            Column(children: [
              if (!readOnly)
                SizedBox(
                    width: 44,
                    height: 44,
                    child: Checkbox(
                      value: entry.eaten,
                      semanticLabel: AppStrings.eatenLabel(entry.name),
                      shape: const CircleBorder(),
                      onChanged: (_) => onToggle(),
                    ))
              else
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                        entry.eaten ? Icons.check_circle : Icons.lock_outline,
                        color: AppPalette.muted,
                        size: 20)),
              if (!readOnly)
                PopupMenuButton<String>(
                  tooltip: AppStrings.mealActions,
                  icon: const Icon(Icons.more_horiz,
                      size: 20, color: AppPalette.muted),
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text(AppStrings.edit)),
                    PopupMenuItem(
                        value: 'delete', child: Text(AppStrings.delete)),
                  ],
                ),
            ]),
          ]),
        ),
      );
}
