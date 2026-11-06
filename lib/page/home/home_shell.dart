import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../l10n/app_strings.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/motion_settings.dart';
import '../me/me_tab.dart';
import '../nutrition/nutrition_tab.dart';
import '../progress/progress_tab.dart';
import '../today/today_tab.dart';
import '../training/training_tab.dart';
import 'home_controller.dart';

class HomeShell extends GetView<HomeController> {
  const HomeShell({super.key, this.tabs});
  final List<Widget>? tabs;

  // The assistant is reached through Today's labelled action.
  static const _destinations = [
    (Icons.home_rounded, Icons.home_outlined, AppStrings.today),
    (Icons.restaurant_rounded, Icons.restaurant_outlined, AppStrings.nutrition),
    (
      Icons.fitness_center_rounded,
      Icons.fitness_center_outlined,
      AppStrings.training
    ),
    (Icons.insights_rounded, Icons.insights_outlined, AppStrings.progress),
    (Icons.person_rounded, Icons.person_outline, AppStrings.me),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final index = controller.tabIndex.value;
      return GlassScaffold(
        // IndexedStack, not a torn-down-and-rebuilt switcher: My Meals and
        // Today both hold live Firestore stream subscriptions and scroll
        // position that must survive a tab switch, not restart on every
        // tap. The nav bar's own icon-swap and pill already carry the
        // "something changed" feedback for a tab switch.
        body: IndexedStack(
          index: index,
          children: tabs ??
              const [
                TodayTab(),
                NutritionTab(),
                TrainingTab(),
                ProgressTab(),
                MeTab(),
              ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppPalette.outline)),
          ),
          child: NavigationBar(
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: index,
            onDestinationSelected: controller.selectTab,
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  icon: Icon(destination.$2),
                  selectedIcon: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MotionSettings.duration(
                        context, const Duration(milliseconds: 180)),
                    builder: (_, value, child) => Transform.scale(
                      scale: .92 + .08 * value,
                      child: Opacity(opacity: .7 + .3 * value, child: child),
                    ),
                    child: Icon(destination.$1, color: AppPalette.emerald),
                  ),
                  label: destination.$3,
                ),
            ],
          ),
        ),
      );
    });
  }
}
