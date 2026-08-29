import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/day/day_log.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/schedule/schedule_item.dart';
import '../../service/auth_service.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/error_state.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/navigation.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../meal_editor/meal_editor_screen.dart';
import 'my_meals_controller.dart';

const _weekdayLabels = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

/// "وجباتي": two sub-tabs, مكتبتي (the meal library) and جدولي (the
/// recurring schedule). Lives inside [HomeShell]'s `IndexedStack`, so its
/// controller and stream subscriptions must survive being scrolled away from
/// and back to -- see the home shell's doc comment on why it isn't rebuilt.
class MyMealsTab extends StatefulWidget {
  const MyMealsTab({super.key});

  @override
  State<MyMealsTab> createState() => _MyMealsTabState();
}

class _MyMealsTabState extends State<MyMealsTab> {
  late final MyMealsController controller =
      MyMealsController(uid: Get.find<AuthService>().currentUser!.uid);

  @override
  void initState() {
    super.initState();
    // GetxController.onInit() is normally invoked by GetX's own DI machinery
    // (Get.put/lazyPut/a Binding) when the instance is registered. This
    // controller is deliberately a plain, screen-scoped object instead --
    // nothing outside this tab needs to Get.find it -- so nothing calls
    // onInit() unless this does. Without this line the library/schedule
    // streams are never subscribed to at all: not slow, not erroring, just
    // never started, and both tabs spin forever with zero signal why.
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  Future<void> _openEditor([String? mealId]) async {
    await pushHealthak(() => MealEditorScreen(mealId: mealId));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const SizedBox(height: 56),
            const TabBar(
              tabs: [Tab(text: 'مكتبتي'), Tab(text: 'جدولي')],
              indicatorColor: AppPalette.emerald,
              labelColor: AppPalette.text,
              unselectedLabelColor: AppPalette.muted,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _LibraryView(controller: controller, onOpen: _openEditor),
                  _ScheduleView(controller: controller),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LibraryView extends StatelessWidget {
  final MyMealsController controller;
  final void Function([String? mealId]) onOpen;

  const _LibraryView({required this.controller, required this.onOpen});

  @override
  Widget build(BuildContext context) => Obx(() {
        if (controller.libraryLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final libraryError = controller.libraryError.value;
        if (libraryError != null) {
          return ErrorState(
              message: libraryError, onRetry: controller.retryLibrary);
        }
        final meals = controller.library;
        if (meals.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'لا توجد وجبات بعد',
                  message: 'أنشئ أول وجبة من المكوّنات المتاحة',
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                    onPressed: () => onOpen(), child: const Text('وجبة جديدة')),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
          itemCount: meals.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final meal = meals[index];
            return StaggeredEntry(
              index: index,
              maxStaggered: 6,
              child: Dismissible(
                key: ValueKey(meal.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppPalette.danger.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppPalette.danger),
                ),
                confirmDismiss: (_) => showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('حذف الوجبة؟'),
                    content: Text('سيتم حذف "${meal.name}" نهائياً.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('إلغاء')),
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('حذف')),
                    ],
                  ),
                ),
                onDismissed: (_) => controller.deleteMeal(meal.id),
                child: _MealCard(meal: meal, onTap: () => onOpen(meal.id)),
              ),
            );
          },
        );
      });
}

class _MealCard extends StatelessWidget {
  final MealDefinition meal;
  final VoidCallback onTap;

  const _MealCard({required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(meal.name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (meal.isCopy) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.storefront_outlined,
                          size: 14, color: AppPalette.violet),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    '${meal.totalsCache.kcal.round()} سعرة  •  '
                    '${meal.leafCount} مكوّن'
                    '${meal.hasNesting ? "  •  متداخلة" : ""}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppPalette.muted),
          ],
        ),
      );
}

class _ScheduleView extends StatelessWidget {
  final MyMealsController controller;

  const _ScheduleView({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() {
        if (controller.scheduleLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final scheduleError = controller.scheduleError.value;
        if (scheduleError != null) {
          return ErrorState(
              message: scheduleError, onRetry: controller.retrySchedule);
        }
        final slots = MealSlot.values
            .where((slot) => controller.forSlot(slot).isNotEmpty)
            .toList();
        if (slots.isEmpty) {
          return const EmptyState(
            icon: Icons.event_repeat_outlined,
            title: 'لا يوجد جدول بعد',
            message: 'أضف وجبة من مكتبتك لجدولك اليومي',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
          children: [
            for (final slot in slots) ...[
              Padding(
                padding: const EdgeInsets.only(
                    bottom: AppSpacing.xs, top: AppSpacing.sm),
                child: Text(slot.labelAr,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppPalette.emerald)),
              ),
              for (final item in controller.forSlot(slot)) ...[
                _ScheduleCard(controller: controller, item: item),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ],
        );
      });
}

class _ScheduleCard extends StatelessWidget {
  final MyMealsController controller;
  final ScheduleItem item;

  const _ScheduleCard({required this.controller, required this.item});

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: item.active ? 1 : .5,
                    child: Text(item.name,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                IconButton(
                  onPressed: () => controller.move(item, up: true),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                  tooltip: 'أعلى',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => controller.move(item, up: false),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  tooltip: 'أسفل',
                  visualDensity: VisualDensity.compact,
                ),
                Switch(
                  value: item.active,
                  onChanged: (_) => controller.toggleActive(item),
                  activeTrackColor: AppPalette.emerald,
                ),
              ],
            ),
            Text('${item.totals.kcal.round()} سعرة',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 4,
              children: [
                for (var day = 1; day <= 7; day++)
                  _DayDot(
                    label: _weekdayLabels[day - 1],
                    selected: item.daysOfWeek.contains(day),
                    onTap: () => controller.toggleDay(item, day),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final ok = await controller.quickAddToday(item);
                    if (context.mounted) {
                      GlassSnackBar.show(
                        context,
                        ok ? 'أُضيفت لليوم' : 'تعذرت الإضافة',
                        tone:
                            ok ? GlassSnackTone.success : GlassSnackTone.error,
                      );
                    }
                  },
                  icon: const Icon(Icons.today_outlined, size: 16),
                  label: const Text('أضف لليوم'),
                ),
                IconButton(
                  onPressed: () => controller.deleteScheduleItem(item.id),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppPalette.danger),
                ),
              ],
            ),
          ],
        ),
      );
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayDot(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? AppPalette.emerald.withValues(alpha: .25)
                : Colors.white.withValues(alpha: .06),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppPalette.emerald : AppPalette.muted,
                fontWeight: FontWeight.w700,
              )),
        ),
      );
}
