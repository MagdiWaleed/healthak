import 'package:flutter/material.dart';

import '../../ui/components/empty_state.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import 'meal_editor_controller.dart';

/// Bottom sheet for "إضافة وجبة" -- nesting another meal from the library as
/// a component of the one being edited.
///
/// Illegal choices (would close a cycle, exceed nesting depth, or exceed the
/// leaf-count ceiling) are shown greyed out with their Arabic refusal reason
/// rather than hidden, so tapping one explains itself instead of the option
/// silently not being there.
class MealPickerSheet extends StatelessWidget {
  final MealEditorController controller;

  const MealPickerSheet({required this.controller, super.key});

  static Future<void> show(
    BuildContext context,
    MealEditorController controller,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MealPickerSheet(controller: controller),
      );

  @override
  Widget build(BuildContext context) {
    final meals = controller.otherMeals;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(top: media.padding.top + 80),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg)),
        // A flat GlassCard-family surface, not GlassSurface: the meal editor
        // can be reached from a route that already has the nav bar's blur
        // mounted, and this app never runs more than two blurred surfaces at
        // once.
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppPalette.surface.withValues(alpha: .97)),
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
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
                child: Row(children: [
                  Text('اختر وجبة لإضافتها كمكوّن',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppPalette.text,
                      )),
                ]),
              ),
              Flexible(
                child: meals.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: EmptyState(
                          icon: Icons.restaurant_menu,
                          title: 'لا توجد وجبات أخرى',
                          message: 'أنشئ وجبة أخرى أولاً لتتمكن من دمجها هنا',
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.fromLTRB(AppSpacing.md,
                            AppSpacing.xs, AppSpacing.md, media.padding.bottom + 24),
                        itemCount: meals.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final meal = meals[index];
                          final check = controller.checkNest(meal);
                          return Opacity(
                            opacity: check.allowed ? 1 : .45,
                            child: GlassCard(
                              onTap: check.allowed
                                  ? () {
                                      final refusal =
                                          controller.addMealRef(meal);
                                      Navigator.of(context).pop();
                                      if (refusal != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                                SnackBar(content: Text(refusal)));
                                      }
                                    }
                                  : () => ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text(check.messageAr!))),
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
                                        const SizedBox(height: 2),
                                        Text(
                                          '${meal.totalsCache.kcal.round()} سعرة  •  '
                                          '${meal.leafCount} مكوّن',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!check.allowed)
                                    const Icon(Icons.block_rounded,
                                        color: AppPalette.danger, size: 20)
                                  else
                                    const Icon(Icons.add_circle_outline,
                                        color: AppPalette.emerald),
                                ],
                              ),
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
