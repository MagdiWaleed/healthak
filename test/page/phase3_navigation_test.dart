import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/home/home_controller.dart';
import 'package:diet_app2/page/home/home_shell.dart';
import 'package:diet_app2/page/me/me_tab.dart';
import 'package:diet_app2/page/nutrition/nutrition_tab.dart';
import 'package:diet_app2/page/progress/weight_entry_sheet.dart';
import 'package:diet_app2/service/session_controller.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _SessionFake extends GetxController implements SessionController {
  @override
  final profile = Rxn<UserProfile>();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('shell has five labelled destinations and switches tabs',
      (tester) async {
    final home = Get.put(HomeController());
    await tester.pumpWidget(const MaterialApp(
        home: HomeShell(tabs: [
      Center(child: Text('today body')),
      Center(child: Text('nutrition body')),
      Center(child: Text('training body')),
      Center(child: Text('progress body')),
      Center(child: Text('me body')),
    ])));
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(5));
    expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
    expect(find.text(AppStrings.today), findsOneWidget);
    expect(find.text(AppStrings.nutrition), findsOneWidget);
    expect(find.text(AppStrings.training), findsOneWidget);
    expect(find.text(AppStrings.progress), findsOneWidget);
    expect(find.text(AppStrings.me), findsOneWidget);
    await tester.tap(find.text(AppStrings.progress));
    await tester.pumpAndSettle();
    expect(home.tabIndex.value, HomeTab.progress.index);
    expect(find.text('progress body').hitTestable(), findsOneWidget);
    home.goTo(HomeTab.training);
    await tester.pumpAndSettle();
    expect(find.text('training body').hitTestable(), findsOneWidget);
  });

  testWidgets('nutrition segmented control keeps both pages alive',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: NutritionTab(
      tabs: [Text('library'), Text('marketplace')],
    ))));
    expect(find.text('library', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text(AppStrings.market));
    await tester.pumpAndSettle();
    expect(find.text('marketplace').hitTestable(), findsOneWidget);
    expect(find.text('library', skipOffstage: false), findsOneWidget);
  });

  testWidgets('weight entry rejects invalid values and saves 72.5',
      (tester) async {
    double? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WeightEntrySheet(
      saveWeight: (_, kg) async => saved = kg,
    ))));
    final field = find.byType(TextField);
    for (final value in ['', '0', '400']) {
      await tester.enterText(field, value);
      await tester.tap(find.text(AppStrings.save));
      await tester.pump();
      expect(find.text(AppStrings.invalidWeight), findsOneWidget);
      expect(saved, isNull);
    }
    await tester.enterText(field, '72.5');
    await tester.tap(find.text(AppStrings.save));
    await tester.pump();
    expect(saved, 72.5);
  });

  testWidgets('weight entry accepts Arabic-Indic digits', (tester) async {
    double? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WeightEntrySheet(
      saveWeight: (_, kg) async => saved = kg,
    ))));
    await tester.enterText(find.byType(TextField), '٧٢٫٥');
    await tester.tap(find.text(AppStrings.save));
    await tester.pump();
    expect(saved, 72.5);
  });

  testWidgets('Me shows account destinations', (tester) async {
    Get.put<SessionController>(_SessionFake());
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Scaffold(body: MeTab()),
    )));
    await tester.pumpAndSettle();
    for (final label in [
      AppStrings.profileAndGoals,
      AppStrings.goalWeight,
      AppStrings.history,
      AppStrings.foodCatalog,
      AppStrings.budget,
      AppStrings.signOut
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
