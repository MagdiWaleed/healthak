import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_routes.dart';
import '../../l10n/app_strings.dart';
import '../../service/auth_service.dart';
import '../../service/prefs_service.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/motion/navigation.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/glass_tokens.dart';
import '../meal_editor/meal_editor_screen.dart';
import '../my_meals/my_meals_tab.dart';
import '../today/today_tab.dart';
import 'home_controller.dart';

/// Stable identity for the library's create-meal action.
abstract final class HomeShellKeys {
  static const quickAddFab = ValueKey('quick-add-fab');
}

class HomeShell extends GetView<HomeController> {
  const HomeShell({super.key});

  // The assistant is reached through Today's labelled action.
  static const _destinations = [
    (Icons.today_rounded, Icons.today_outlined, AppStrings.today),
    (Icons.restaurant_menu, Icons.restaurant_menu, AppStrings.myMeals),
    (Icons.storefront_rounded, Icons.storefront_outlined, AppStrings.market),
    (Icons.person_rounded, Icons.person_outline, AppStrings.account),
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
          children: [
            const TodayTab(),
            const MyMealsTab(),
            const _Placeholder(
                title: AppStrings.market, icon: Icons.storefront_outlined),
            _AccountTab(
              onGallery: () => Get.toNamed(AppRoutes.gallery),
              onSignOut: () async {
                await Get.find<AuthService>().signOut();
                await Get.find<PrefsService>().clearProfile();
                await Get.offAllNamed(AppRoutes.guest);
              },
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppPalette.outline)),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: controller.selectTab,
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  icon: Icon(destination.$2),
                  selectedIcon: Icon(destination.$1, color: AppPalette.emerald),
                  label: destination.$3,
                ),
            ],
          ),
        ),
        floatingActionButton: index == 1
            ? FloatingActionButton.extended(
                key: HomeShellKeys.quickAddFab,
                onPressed: () => pushHealthak(() => const MealEditorScreen()),
                backgroundColor: AppPalette.emerald,
                foregroundColor: AppPalette.onAccent,
                elevation: 0,
                icon: const Icon(Icons.add_rounded),
                label: const Text(AppStrings.newMeal),
              )
            : null,
      );
    });
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  final IconData icon;
  const _Placeholder({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 58, color: AppPalette.muted),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          Text(AppStrings.comingNext,
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}

class _AccountTab extends StatelessWidget {
  final VoidCallback onGallery;
  final Future<void> Function() onSignOut;
  const _AccountTab({required this.onGallery, required this.onSignOut});

  @override
  Widget build(BuildContext context) => ListView(
        // Bounces even when the row list fits the screen, so dragging down
        // still refracts the shared glass edge instead of doing nothing.
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(22, 88, 22, 120),
        children: [
          Text(AppStrings.account,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          _AccountRow(
            specularIndex: 0,
            icon: Icons.person_outline,
            label: 'الملف الشخصي والأهداف',
            onTap: () => Get.toNamed(AppRoutes.profile),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AccountRow(
            specularIndex: 1,
            icon: Icons.calendar_month_outlined,
            label: 'السجل',
            onTap: () => Get.toNamed(AppRoutes.history),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AccountRow(
            specularIndex: 2,
            icon: Icons.egg_alt_outlined,
            label: 'تصفح المكوّنات',
            onTap: () => Get.toNamed(AppRoutes.foods),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AccountRow(
            specularIndex: 3,
            icon: Icons.payments_outlined,
            label: 'الميزانية',
            onTap: () => Get.toNamed(AppRoutes.cost),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AccountRow(
            specularIndex: 4,
            icon: Icons.palette_outlined,
            label: 'معرض التصميم',
            onTap: onGallery,
          ),
          const SizedBox(height: AppSpacing.xl),
          _AccountRow(
            specularIndex: 5,
            icon: Icons.logout,
            label: 'تسجيل الخروج',
            danger: true,
            onTap: onSignOut,
          ),
        ],
      );
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final int specularIndex;

  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.specularIndex,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => GlassCard(
        specularAngleOffset: specularIndex * GlassTokens.listSpecularStepDeg,
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: danger ? AppPalette.danger : AppPalette.emerald),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: danger ? AppPalette.danger : AppPalette.text)),
            ),
            if (!danger)
              const Icon(Icons.chevron_left_rounded, color: AppPalette.muted),
          ],
        ),
      );
}
