import 'package:flutter/material.dart';

import '../../domain/day/day_log.dart';
import '../../domain/schedule/schedule_item.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/components/glass_chip.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';

/// What "أضف لجدولي" needs from the user: which slot, which days.
class ScheduleChoice {
  final MealSlot slot;
  final Set<int> daysOfWeek;

  const ScheduleChoice({required this.slot, required this.daysOfWeek});
}

const _weekdayLabels = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];

/// Bottom sheet for choosing a slot and a set of weekdays before a meal is
/// added to the recurring schedule.
class ScheduleSheet extends StatefulWidget {
  const ScheduleSheet({super.key});

  static Future<ScheduleChoice?> show(BuildContext context) =>
      GlassSheet.show<ScheduleChoice>(
        context,
        builder: (_) => const ScheduleSheet(),
      );

  @override
  State<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<ScheduleSheet> {
  MealSlot _slot = MealSlot.breakfast;
  Set<int> _days = Set.of(ScheduleItem.everyDay);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return GlassSheet(
      title: 'إضافة للجدول',
      topInset: 160,
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
            AppSpacing.md, media.padding.bottom + AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                const Text('الوقت', style: TextStyle(color: AppPalette.muted)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final slot in MealSlot.values)
                      GlassChip(
                        label: slot.labelAr,
                        selected: _slot == slot,
                        onTap: () => setState(() => _slot = slot),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Text('الأيام', style: TextStyle(color: AppPalette.muted)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(
                          () => _days = Set.of(ScheduleItem.everyDay)),
                      child: const Text('كل يوم'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      GlassChip(
                        label: _weekdayLabels[day - 1],
                        selected: _days.contains(day),
                        onTap: () => setState(() {
                          if (!_days.remove(day)) _days.add(day);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                GlassButton(
                  label: 'إضافة',
                  onPressed: _days.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            ScheduleChoice(slot: _slot, daysOfWeek: _days),
                          ),
                ),
          ],
        ),
      ),
    );
  }
}
