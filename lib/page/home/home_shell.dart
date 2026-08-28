import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_routes.dart';
import '../../domain/nutrition/macros.dart';
import '../../l10n/app_strings.dart';
import '../../service/auth_service.dart';
import '../../service/prefs_service.dart';
import '../../ui/components/calorie_ring.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_panel.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/motion/pressable.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import 'home_controller.dart';

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
  Widget build(BuildContext context) => Obx(() {
        final index = controller.tabIndex.value;
        return GlassScaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(0, .015), end: Offset.zero),
                ),
                child: child,
              ),
            ),
            // Keying by tab is what tells AnimatedSwitcher a new page arrived
            // rather than the same one rebuilding.
            child: KeyedSubtree(
              key: ValueKey(index),
              child: switch (index) {
                0 => const _TodayTab(),
                1 => const _Placeholder(
                    title: AppStrings.myMeals, icon: Icons.restaurant_menu),
                2 => const _Placeholder(
                    title: AppStrings.market, icon: Icons.storefront_outlined),
                _ => _AccountTab(
                    onGallery: () => Get.toNamed(AppRoutes.gallery),
                    onSignOut: () async {
                      await Get.find<AuthService>().signOut();
                      await Get.find<PrefsService>().clearProfile();
                      await Get.offAllNamed(AppRoutes.guest);
                    },
                  ),
              },
            ),
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.comingNext)),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        );
      });
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

class _TodayTab extends StatelessWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = <Widget>[
      Text('صباح الخير', style: text.headlineMedium),
      const SizedBox(height: 4),
      Text('خطتك الغذائية واضحة أمامك', style: text.bodyLarge),
      const SizedBox(height: AppSpacing.xl),
      const Center(
        child: CalorieRing(
          consumed: 840,
          target: 2000,
          consumedMacros: Macros(protein: 62, carbs: 88, fat: 31),
          targetMacros: Macros(protein: 130, carbs: 230, fat: 65),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      const GlassCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_clock_outlined, color: AppPalette.emerald),
          title: Text('وجبات اليوم'),
          subtitle: Text(AppStrings.comingNext),
        ),
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 120),
      itemCount: rows.length,
      itemBuilder: (context, i) =>
          StaggeredEntry(index: i, child: rows[i]),
    );
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
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FilledButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.palette_outlined),
            label: const Text('معرض التصميم'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
          ),
        ]),
      );
}
