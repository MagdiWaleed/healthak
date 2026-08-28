import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../page/dev/gallery_screen.dart';
import '../page/foods/food_catalog_screen.dart';
import '../page/guest/guest_preview_screen.dart';
import '../page/history/history_screen.dart';
import '../page/home/home_shell.dart';
import '../page/onboarding/onboarding_screen.dart';
import '../page/profile/profile_screen.dart';
import '../page/splash/splash_screen.dart';
import '../ui/motion/transitions.dart';
import 'app_routes.dart';
import 'bindings/food_catalog_binding.dart';
import 'bindings/home_binding.dart';
import 'bindings/onboarding_binding.dart';
import 'bindings/splash_binding.dart';

/// Legacy `/legacy` fallback route (and `LegacyLtrShim`) were deleted here in
/// Step 2's replacement pass: every screen it could have reached
/// (`MainScreen`, `single_male_screen`, `add_complete_meal`, `my_informations`,
/// `current_diet`, `sign_in`, `loading`, `setting`, `diet_details`) now has a
/// verified new-code replacement -- see `plans/PROGRESS.md`'s Step 2 section.
/// `lib/ui/legacy_ltr_shim.dart` itself is left in place; Step 4 owns
/// deleting the file as part of its RTL sweep.
abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    _page(AppRoutes.splash, () => const SplashScreen(),
        binding: SplashBinding()),
    _page(AppRoutes.guest, () => const GuestPreviewScreen()),
    _page(AppRoutes.onboarding, () => const OnboardingScreen(),
        binding: OnboardingBinding()),
    _page(AppRoutes.home, () => const HomeShell(), binding: HomeBinding()),
    _page(AppRoutes.gallery, () => const GalleryScreen()),
    _page(AppRoutes.profile, () => const ProfileScreen()),
    _page(AppRoutes.history, () => const HistoryScreen()),
    _page(AppRoutes.foods, () => const FoodCatalogScreen(),
        binding: FoodCatalogBinding()),
  ];

  static GetPage<dynamic> _page(
    String name,
    Widget Function() page, {
    Bindings? binding,
  }) =>
      GetPage(
        name: name,
        page: page,
        binding: binding,
        customTransition: HealthakTransition(),
        transitionDuration: const Duration(milliseconds: 250),
      );
}
