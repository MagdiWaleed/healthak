import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../appData.dart';
import '../page/dev/gallery_screen.dart';
import '../page/guest/guest_preview_screen.dart';
import '../page/home/home_shell.dart';
import '../page/main_screen/main_screen.dart';
import '../page/onboarding/onboarding_screen.dart';
import '../page/splash/splash_screen.dart';
import '../ui/legacy_ltr_shim.dart';
import '../ui/motion/transitions.dart';
import 'app_routes.dart';
import 'bindings/home_binding.dart';
import 'bindings/onboarding_binding.dart';
import 'bindings/splash_binding.dart';

abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    _page(AppRoutes.splash, () => const SplashScreen(),
        binding: SplashBinding()),
    _page(AppRoutes.guest, () => const GuestPreviewScreen()),
    _page(AppRoutes.onboarding, () => const OnboardingScreen(),
        binding: OnboardingBinding()),
    _page(AppRoutes.home, () => const HomeShell(), binding: HomeBinding()),
    _page(AppRoutes.gallery, () => const GalleryScreen()),
    _page(
      AppRoutes.legacy,
      () => LegacyLtrShim(child: MainScreen(me: appData.getUserModel())),
    ),
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
