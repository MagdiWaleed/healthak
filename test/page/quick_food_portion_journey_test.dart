import 'dart:async';

import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/food/food_item.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/today/quick_food_portion_sheet.dart';
import 'package:diet_app2/page/today/today_controller.dart';
import 'package:diet_app2/ui/components/glass_button.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _QuickController extends GetxController implements TodayController {
  final writes = <({double grams, MealSlot? slot})>[];
  Completer<void> completion = Completer<void>();
  @override
  final day =
      Rxn<DayLog>(DayLog.empty(DateTime(2026, 10, 23), NutritionTargets.empty));
  @override
  bool get canEditSelectedDay => true;
  @override
  Future<void> quickAddFood(FoodItem food,
      {double grams = 100, MealSlot? slot}) {
    writes.add((grams: grams, slot: slot));
    return completion.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const food = FoodItem(
    id: 'food-test',
    name: 'Kabsa',
    per100: Macros(protein: 10, carbs: 20, fat: 5),
  );

  Future<void> open(WidgetTester tester, _QuickController controller) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  QuickFoodPortionSheet.show(context, controller, food),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'food selection requires a reviewed positive portion before write',
      (tester) async {
    final controller = _QuickController();
    await open(tester, controller);
    expect(controller.writes, isEmpty);
    expect(find.text(AppStrings.portionCalories(165)), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    expect(find.text(AppStrings.invalidPortion), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(controller.writes, isEmpty);

    await tester.enterText(find.byType(TextField), '150');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.portionCalories(248)), findsOneWidget);
    await tester.ensureVisible(find.byType(GlassButton));
    await tester.tap(find.text(AppStrings.addToDay));
    await tester.pump();
    expect(controller.writes.single.grams, 150);
    expect(controller.writes.single.slot, isNull);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    controller.completion.completeError(StateError('network failure'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.quickFoodSaveFailed), findsOneWidget);
    expect(find.text('150'), findsOneWidget);

    controller.completion = Completer<void>();
    await tester.tap(find.text(AppStrings.addToDay));
    await tester.pump();
    controller.completion.complete();
    await tester.pumpAndSettle();
    expect(find.byType(QuickFoodPortionSheet), findsNothing);
    expect(controller.writes.length, 2);
  });
}
