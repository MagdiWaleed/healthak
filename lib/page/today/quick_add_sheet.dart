import 'package:flutter/material.dart';

import '../../data/repositories/meal_repository.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/meal/meal_math.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/motion/navigation.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../foods/food_picker_sheet.dart';
import '../meal_editor/meal_editor_screen.dart';
import 'manual_entry_sheet.dart';
import 'today_controller.dart';

/// The Today FAB's menu: [أضف وجبة من مكتبتي / أضف مكوّناً سريعاً /
/// أضف عنصراً يدوياً / أنشئ وجبة جديدة]. All four add to today only -- see
/// the controller's `isViewingToday` guard.
class QuickAddSheet {
  static Future<void> show(BuildContext context, TodayController controller) =>
      GlassSheet.show<void>(
        context,
        isScrollControlled: false,
        builder: (sheetContext) => _QuickAddMenu(
          controller: controller,
          onPickLibraryMeal: () {
            Navigator.of(sheetContext).pop();
            _LibraryMealSheet.show(context, controller);
          },
          onQuickFood: () async {
            Navigator.of(sheetContext).pop();
            final food = await FoodPickerSheet.show(context);
            if (food != null) await controller.quickAddFood(food);
          },
          onManualEntry: () {
            Navigator.of(sheetContext).pop();
            ManualEntrySheet.show(context, controller);
          },
          onNewMeal: () {
            Navigator.of(sheetContext).pop();
            pushHealthak(() => const MealEditorScreen());
          },
        ),
      );
}

class _QuickAddMenu extends StatelessWidget {
  final TodayController controller;
  final VoidCallback onPickLibraryMeal;
  final VoidCallback onQuickFood;
  final VoidCallback onManualEntry;
  final VoidCallback onNewMeal;

  const _QuickAddMenu({
    required this.controller,
    required this.onPickLibraryMeal,
    required this.onQuickFood,
    required this.onManualEntry,
    required this.onNewMeal,
  });

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return GlassSheet(
      topInset: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, bottomSafe),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuTile(
              icon: Icons.restaurant_menu,
              label: 'أضف وجبة من مكتبتي',
              onTap: onPickLibraryMeal,
            ),
            _MenuTile(
              icon: Icons.bolt_rounded,
              label: 'أضف مكوّناً سريعاً',
              onTap: onQuickFood,
            ),
            _MenuTile(
              icon: Icons.edit_note_rounded,
              label: 'أضف عنصراً يدوياً',
              onTap: onManualEntry,
            ),
            _MenuTile(
              icon: Icons.add_circle_outline,
              label: 'أنشئ وجبة جديدة',
              onTap: onNewMeal,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppPalette.emerald),
        title: Text(label),
      );
}

/// Second step of "أضف وجبة من مكتبتي": the library, fetched fresh rather
/// than through My Meals' cached stream, so this sheet stays decoupled from
/// whichever tab happens to be mounted.
class _LibraryMealSheet extends StatefulWidget {
  final TodayController controller;
  const _LibraryMealSheet({required this.controller});

  static Future<void> show(BuildContext context, TodayController controller) =>
      GlassSheet.show<void>(
        context,
        builder: (_) => _LibraryMealSheet(controller: controller),
      );

  @override
  State<_LibraryMealSheet> createState() => _LibraryMealSheetState();
}

class _LibraryMealSheetState extends State<_LibraryMealSheet> {
  List<MealDefinition>? _meals;

  @override
  void initState() {
    super.initState();
    MealRepository(uid: widget.controller.uid).getAll().then((value) {
      if (mounted) setState(() => _meals = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final meals = _meals;
    return GlassSheet(
      title: 'اختر وجبة من مكتبتك',
      topInset: 80,
      expand: true,
      child: meals == null
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(),
            )
          : meals.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: EmptyState(
                    icon: Icons.restaurant_menu,
                    title: 'لا توجد وجبات بعد',
                    message: 'أنشئ وجبة أولاً من تبويب وجباتي',
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs,
                      AppSpacing.md, media.padding.bottom + 24),
                  itemCount: meals.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    return GlassCard(
                      onTap: () async {
                        await widget.controller.addLibraryMeal(
                          meal,
                          MealResolver(meals),
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(meal.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Text('${meal.totalsCache.kcal.round()} سعرة',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                          const Icon(Icons.add_circle_outline,
                              color: AppPalette.emerald),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
