import 'package:diet_app2/domain/meal/meal_entry.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/meal_editor/meal_editor_controller.dart';
import 'package:diet_app2/page/meal_editor/meal_editor_screen.dart';
import 'package:diet_app2/ui/theme/app_colors.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Editor extends GetxController implements MealEditorController {
  @override
  final lockedIds = <String>{}.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('meal entry name and controls fit at 320px and 1.6 text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const name = 'بيض مقلي مع خبز القمح الكامل';
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: const MediaQueryData(
            textScaler: TextScaler.linear(1.6), disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              body: ReorderableListView(onReorder: (_, __) {}, children: [
            MealEditorEntryRow(
              key: const ValueKey('egg'),
              controller: _Editor(),
              entry: const FoodEntry(
                  localId: 'egg',
                  order: 0,
                  foodId: 'egg',
                  name: name,
                  per100: Macros(protein: 12, carbs: 1, fat: 10),
                  grams: 100),
              index: 0,
              onSnack: (_, {undo, tone}) {},
            ),
          ])),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(name), findsOneWidget);
    expect(tester.widget<Text>(find.text(name)).maxLines, 2);
    expect(find.text('100 ${AppStrings.grams}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal saved feedback has success icon and border',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () => MealEditorScreen.showSavedSnack(context),
        child: const Text('save'),
      ),
    ))));
    await tester.tap(find.text('save'));
    await tester.pump();
    expect(find.text(AppStrings.mealSaved), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            ((widget.decoration! as BoxDecoration).border as Border?)
                    ?.top
                    .color ==
                AppPalette.emerald),
        findsOneWidget);
  });
}
