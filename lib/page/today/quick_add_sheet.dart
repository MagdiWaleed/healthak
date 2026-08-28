import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/meal_repository.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/meal/meal_math.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../foods/food_picker_sheet.dart';
import '../meal_editor/meal_editor_screen.dart';
import 'today_controller.dart';

/// The Today FAB's menu: [أضف وجبة من مكتبتي / أضف مكوّناً سريعاً /
/// أنشئ وجبة جديدة]. All three add to today only -- see the controller's
/// `isViewingToday` guard.
class QuickAddSheet {
  static Future<void> show(BuildContext context, TodayController controller) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
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
          onNewMeal: () {
            Navigator.of(sheetContext).pop();
            Get.to(() => const MealEditorScreen());
          },
        ),
      );
}

class _QuickAddMenu extends StatelessWidget {
  final TodayController controller;
  final VoidCallback onPickLibraryMeal;
  final VoidCallback onQuickFood;
  final VoidCallback onNewMeal;

  const _QuickAddMenu({
    required this.controller,
    required this.onPickLibraryMeal,
    required this.onQuickFood,
    required this.onNewMeal,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.surface.withValues(alpha: .97),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
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
                    icon: Icons.add_circle_outline,
                    label: 'أنشئ وجبة جديدة',
                    onTap: onNewMeal,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.onTap});

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
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
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
    return Padding(
      padding: EdgeInsets.only(top: media.padding.top + 80),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg)),
        child: DecoratedBox(
          decoration:
              BoxDecoration(color: AppPalette.surface.withValues(alpha: .97)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(children: [
                  Text('اختر وجبة من مكتبتك',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppPalette.text)),
                ]),
              ),
              Flexible(
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
                            shrinkWrap: true,
                            padding: EdgeInsets.fromLTRB(AppSpacing.md,
                                AppSpacing.xs, AppSpacing.md,
                                media.padding.bottom + 24),
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
                                  if (context.mounted) Navigator.of(context).pop();
                                },
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(meal.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                          Text(
                                              '${meal.totalsCache.kcal.round()} سعرة',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
