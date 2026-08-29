import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_routes.dart';
import '../../l10n/app_strings.dart';
import '../../service/auth_service.dart';
import '../../service/prefs_service.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_panel.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/motion/pressable.dart';
import '../../ui/motion/navigation.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/glass_tokens.dart';
import '../meal_editor/meal_editor_screen.dart';
import '../my_meals/my_meals_tab.dart';
import '../today/quick_add_sheet.dart';
import '../today/today_controller.dart';
import '../today/today_tab.dart';
import 'home_controller.dart';

/// The FAB means something different per tab: quick-add on Today, a new meal
/// on My Meals, and "not yet" (Step 3) on Market and Account.
void _onFabPressed(BuildContext context, int tabIndex) {
  switch (tabIndex) {
    case 0:
      final today = Get.find<TodayController>();
      today.ensureCurrentDay();
      if (!today.canEditSelectedDay) {
        GlassSnackBar.show(
          context,
          'اضغط "تعديل" أولاً لتصحيح يوم سابق',
          tone: GlassSnackTone.warning,
        );
        return;
      }
      QuickAddSheet.show(context, today);
    case 1:
      pushHealthak(() => const MealEditorScreen());
    default:
      GlassSnackBar.show(context, AppStrings.comingNext);
  }
}

/// Keys for widgets that widget tests need to locate directly, because they
/// are shared components (e.g. [Pressable]) rather than a distinct type
/// `find.byType` could isolate.
abstract final class HomeShellKeys {
  static const quickAddFab = ValueKey('quick-add-fab');
}

class HomeShell extends GetView<HomeController> {
  const HomeShell({super.key});

  static const _destinations = [
    (Icons.today_rounded, Icons.today_outlined, AppStrings.today),
    (Icons.restaurant_menu, Icons.restaurant_menu, AppStrings.myMeals),
    (Icons.storefront_rounded, Icons.storefront_outlined, AppStrings.market),
    (Icons.person_rounded, Icons.person_outline, AppStrings.account),
  ];

  @override
  Widget build(BuildContext context) {
    // The shell owns the ambient response. Today keeps the controller's
    // lifecycle, while the shell observes its mood so the background can
    // change without rebuilding or resubscribing the tab subtree.
    final today = Get.find<TodayController>();

    return Obx(() {
      final index = controller.tabIndex.value;
      return GlassScaffold(
        mood: today.mood.value,
        lightEventKey: index,
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
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++) ...[
                  Expanded(
                    child: _NavDestination(
                      selected: i == index,
                      filledIcon: _destinations[i].$1,
                      outlineIcon: _destinations[i].$2,
                      label: _destinations[i].$3,
                      onTap: () => controller.selectTab(i),
                    ),
                  ),
                  if (i == 1) const SizedBox(width: 64),
                ],
              ],
            ),
          ),
        ),
        floatingActionButton: _QuickAddFab(
          onPressed: () => _onFabPressed(context, index),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      );
    });
  }
}

/// One nav bar destination: an indicator pill that grows in behind the icon,
/// an icon that swaps between its outline and filled glyph, and a label that
/// only the selected tab shows.
///
/// Icon-swap-on-select plus a label that appears rather than always being
/// present is a deliberately small amount of motion -- this bar is visible on
/// every screen, so anything louder becomes noise within a session.
class _NavDestination extends StatelessWidget {
  final bool selected;
  final IconData filledIcon;
  final IconData outlineIcon;
  final String label;
  final VoidCallback onTap;

  const _NavDestination({
    required this.selected,
    required this.filledIcon,
    required this.outlineIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        pressedScale: .93,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? AppPalette.emerald.withValues(alpha: .16)
                      : Colors.transparent,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: Icon(
                    selected ? filledIcon : outlineIcon,
                    key: ValueKey(selected),
                    color: selected ? AppPalette.emerald : AppPalette.muted,
                    size: 23,
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.text,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
        ),
      );
}

class _QuickAddFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _QuickAddFab({required this.onPressed});

  @override
  Widget build(BuildContext context) => Pressable(
        key: HomeShellKeys.quickAddFab,
        onTap: onPressed,
        haptic: true,
        pressedScale: .90,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppPalette.accentGradient,
            boxShadow: [
              BoxShadow(
                color: AppPalette.emerald.withValues(alpha: .45),
                blurRadius: 24,
                spreadRadius: -2,
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: AppPalette.ink, size: 30),
        ),
      );
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
        specularAngleOffset:
            specularIndex * GlassTokens.listSpecularStepDeg,
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
