import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/profile/body_stats.dart';
import 'package:diet_app2/domain/food/food_item.dart';
import 'package:diet_app2/page/foods/food_detail_screen.dart';
import 'package:diet_app2/page/guest/guest_preview_screen.dart';
import 'package:diet_app2/page/home/home_controller.dart';
import 'package:diet_app2/page/home/home_shell.dart';
import 'package:diet_app2/page/nutrition/nutrition_tab.dart';
import 'package:diet_app2/page/onboarding/onboarding_controller.dart';
import 'package:diet_app2/page/onboarding/onboarding_screen.dart';
import 'package:diet_app2/page/progress/weight_entry_sheet.dart';
import 'package:diet_app2/page/splash/splash_controller.dart';
import 'package:diet_app2/page/splash/splash_screen.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _SplashFake extends GetxController implements SplashController {
  @override
  final error = RxnString();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OnboardingFake extends GetxController implements OnboardingController {
  @override
  final fieldError = Rxn<BodyStatsError>();
  @override
  final collectingProfile = false.obs;
  @override
  final busy = false.obs;
  @override
  final error = RxnString();
  @override
  final isLogin = true.obs;
  @override
  final email = TextEditingController();
  @override
  final password = TextEditingController();
  @override
  final name = TextEditingController();
  @override
  final birthYear = TextEditingController(text: '1995');
  @override
  final height = TextEditingController(text: '170');
  @override
  final weight = TextEditingController(text: '70');
  @override
  final goalWeight = TextEditingController();
  @override
  final sex = Sex.male.obs;
  @override
  final activity = ActivityLevel.moderate.obs;
  @override
  final goal = Goal.maintain.obs;
  @override
  final weeklyRate = .5.obs;
  @override
  final previewTargets = Rxn<NutritionTargets>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  final screens = <(String, Widget, void Function())>[
    ('guest', const GuestPreviewScreen(), () {}),
    (
      'food detail',
      const FoodDetailScreen(
          food: FoodItem(
              id: 'food',
              name: 'طعام تجريبي',
              per100: Macros(protein: 20, carbs: 10, fat: 5))),
      () {}
    ),
    (
      'nutrition',
      const Scaffold(
          body: NutritionTab(tabs: [Text('library'), Text('market')])),
      () {}
    ),
    (
      'home navigation',
      const HomeShell(tabs: [
        Text('today'),
        Text('nutrition'),
        Text('training'),
        Text('progress'),
        Text('me'),
      ]),
      () {
        Get.put<HomeController>(HomeController(), permanent: true);
      }
    ),
    (
      'splash',
      const SplashScreen(),
      () => Get.put<SplashController>(_SplashFake())
    ),
    (
      'onboarding auth',
      const OnboardingScreen(),
      () => Get.put<OnboardingController>(_OnboardingFake())
    ),
    (
      'onboarding profile',
      const OnboardingScreen(),
      () {
        final fake = _OnboardingFake();
        fake.collectingProfile.value = true;
        Get.put<OnboardingController>(fake);
      }
    ),
    ('weight sheet', const WeightEntrySheet(saveWeight: _saveWeight), () {}),
  ];

  for (final (name, screen, setup) in screens) {
    testWidgets('$name fits 320px with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      setup();
      await tester.pumpWidget(GetMaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('ar'),
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.6),
            disableAnimations: true,
          ),
          child: name == 'weight sheet'
              ? Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => screen),
                      child: const Text('open'),
                    ),
                  ),
                )
              : screen,
        ),
      ));
      if (name == 'weight sheet') {
        await tester.tap(find.text('open'));
        await tester.pump();
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _saveWeight(DateTime _, double kg) async {}
