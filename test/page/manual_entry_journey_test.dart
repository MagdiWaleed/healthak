import 'dart:async';

import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/today/manual_entry_sheet.dart';
import 'package:diet_app2/page/today/today_controller.dart';
import 'package:diet_app2/ui/components/glass_button.dart';
import 'package:diet_app2/ui/format/number_input.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _ManualController extends GetxController implements TodayController {
  final writes = <({String name, Macros macros, MealSlot? slot})>[];
  Completer<void> completion = Completer<void>();
  @override
  final day =
      Rxn<DayLog>(DayLog.empty(DateTime(2026, 10, 23), NutritionTargets.empty));
  @override
  bool get canEditSelectedDay => true;
  @override
  Future<void> logCustomEntry(
      {required String name, required Macros macros, MealSlot? slot}) {
    writes.add((name: name, macros: macros, slot: slot));
    return completion.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('nutrition input supports Arabic decimals and rejects unsafe values',
      () {
    expect(parseNutritionAmount('١٠٫٥'), 10.5);
    expect(parseNutritionAmount('۱۲.۵'), 12.5);
    expect(parseNutritionAmount(' 20 '), 20);
    expect(parseNutritionAmount(''), 0);
    for (final invalid in ['-1', 'NaN', 'Infinity', 'abc', '١٢٫٣٫٤']) {
      expect(parseNutritionAmount(invalid), isNull, reason: invalid);
    }
  });

  Future<void> open(WidgetTester tester, _ManualController controller) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () =>
                            ManualEntrySheet.show(context, controller),
                        child: const Text('open')))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'وجبة اختبار');
    await tester.enterText(find.byType(TextField).at(1), '١٠٫٥');
    await tester.enterText(find.byType(TextField).at(2), '٢٠');
    await tester.enterText(find.byType(TextField).at(3), '٥');
    await tester.ensureVisible(find.text(AppStrings.addToDay));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'invalid primary action is disabled and negative macros cannot save',
      (tester) async {
    final controller = _ManualController();
    await open(tester, controller);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await fill(tester);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await tester.enterText(find.byType(TextField).at(1), '-10');
    await tester.pump();
    expect(find.text(AppStrings.invalidNutrition), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(controller.writes, isEmpty);
  });

  testWidgets(
      'save waits, prevents duplicates, preserves input on error and retries',
      (tester) async {
    final controller = _ManualController();
    await open(tester, controller);
    await fill(tester);
    await tester.tap(find.text(AppStrings.addToDay));
    await tester.pump();
    expect(find.text(AppStrings.saving), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(controller.writes.length, 1);
    expect(controller.writes.single.macros.kcal, 167);
    controller.completion.completeError(StateError('network failure'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.saveFailed), findsOneWidget);
    expect(find.text('وجبة اختبار'), findsOneWidget);
    controller.completion = Completer<void>();
    await tester.ensureVisible(find.text(AppStrings.addToDay));
    await tester.tap(find.text(AppStrings.addToDay));
    await tester.pump();
    controller.completion.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ManualEntrySheet), findsNothing);
    expect(find.text(AppStrings.entryAdded), findsOneWidget);
    expect(controller.writes.length, 2);
  });

  testWidgets('manual form scrolls with a keyboard on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await open(tester, _ManualController());
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.showKeyboard(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(GlassButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(GlassButton).hitTestable(), findsOneWidget);
  });
}
