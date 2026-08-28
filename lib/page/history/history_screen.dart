import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/day/day_log.dart';
import '../../service/auth_service.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import 'history_controller.dart';

const _monthNames = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];
const _weekdayInitials = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryController controller =
      HistoryController(uid: Get.find<AuthService>().currentUser!.uid);

  @override
  void initState() {
    super.initState();
    // See the identical note in my_meals_tab.dart / meal_editor_screen.dart:
    // this controller is plain-constructed, not Get.put, so GetX never calls
    // onInit() on its own. Without this, the month never loads.
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassScaffold(
        appBar: AppBar(title: const Text('السجل')),
        body: Obx(() {
          final month = controller.month.value;
          return Column(
            children: [
              const SizedBox(height: 56),
              _MonthHeader(controller: controller),
              const SizedBox(height: AppSpacing.sm),
              if (controller.loading.value)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _MonthGrid(controller: controller, month: month),
                  ),
                ),
            ],
          );
        }),
      );
}

class _MonthHeader extends StatelessWidget {
  final HistoryController controller;
  const _MonthHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final month = controller.month.value;
    final isCurrentMonth = month.year == DateTime.now().year &&
        month.month == DateTime.now().month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            onPressed: controller.previousMonth,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          Expanded(
            child: Center(
              child: Text('${_monthNames[month.month - 1]} ${month.year}',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          IconButton(
            onPressed: isCurrentMonth ? null : controller.nextMonth,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final HistoryController controller;
  final DateTime month;

  const _MonthGrid({required this.controller, required this.month});

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Leading blanks so day 1 lands under its real weekday (Monday-first).
    final leadingBlanks = firstOfMonth.weekday - 1;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppPalette.muted)),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              _DayCell(
                date: DateTime(month.year, month.month, d),
                adherence: controller.adherenceFor(DateTime(month.year, month.month, d)),
                isFuture: DateTime(month.year, month.month, d)
                    .isAfter(DateTime(today.year, today.month, today.day)),
                isToday: month.year == today.year &&
                    month.month == today.month &&
                    d == today.day,
                onTap: () => _openDetail(context, DateTime(month.year, month.month, d)),
              ),
          ],
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, DateTime date) {
    final day = controller.dayFor(date);
    if (day == null) return; // nothing logged that day
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayDetailSheet(date: date, day: day),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final double? adherence;
  final bool isFuture;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.adherence,
    required this.isFuture,
    required this.isToday,
    required this.onTap,
  });

  Color get _tint {
    final a = adherence;
    if (a == null) return Colors.white.withValues(alpha: .04);
    if (a > 1.05) return AppPalette.danger.withValues(alpha: .35);
    // Emerald deepens with adherence -- a day at 20% barely tints, a day at
    // or near target reads clearly as "done".
    return AppPalette.emerald.withValues(alpha: (0.12 + a * 0.35).clamp(0.0, 0.55));
  }

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: isFuture ? .25 : 1,
        child: GestureDetector(
          onTap: (isFuture || adherence == null) ? null : onTap,
          child: Container(
            decoration: BoxDecoration(
              color: _tint,
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(color: AppPalette.emerald, width: 1.4)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text('${date.day}',
                style: const TextStyle(fontSize: 12, color: AppPalette.text)),
          ),
        ),
      );
}

class _DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final DayLog day;

  const _DayDetailSheet({required this.date, required this.day});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: media.padding.top + 140),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg)),
        child: DecoratedBox(
          decoration:
              BoxDecoration(color: AppPalette.surface.withValues(alpha: .97)),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
                AppSpacing.md, media.padding.bottom + AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text('${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppPalette.text)),
                Text(
                  '${day.consumedKcal.round()} من ${day.targets.kcal.round()} سعرة',
                  style: const TextStyle(color: AppPalette.muted),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final slot in day.activeSlots) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(slot.labelAr,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppPalette.emerald)),
                  ),
                  for (final entry in day.entriesForSlot(slot))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Icon(
                              entry.eaten
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: entry.eaten
                                  ? AppPalette.emerald
                                  : AppPalette.muted,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(child: Text(entry.name)),
                            Text('${entry.kcal.round()} سعرة'),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
