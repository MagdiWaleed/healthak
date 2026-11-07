import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/today/today_summary.dart';
import 'package:diet_app2/page/today/today_tab.dart';
import 'package:diet_app2/ui/background/reactive_aurora.dart';
import 'package:diet_app2/ui/background/aurora_background.dart';
import 'package:diet_app2/ui/glass/glass_scaffold.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _food = FrozenItem(
    foodId: 'chicken',
    name: 'دجاج',
    per100: Macros(protein: 30, carbs: 0, fat: 4),
    grams: 100);
const _entry = DayEntry(
    entryId: 'lunch',
    origin: DayEntryOrigin.quickAdd,
    name: 'وجبة الغداء',
    slot: MealSlot.lunch,
    order: 0,
    items: [_food]);

DayLog _day({bool eaten = false, double target = 2000}) => DayLog(
    dateKey: '2026-10-23',
    date: DateTime(2026, 10, 23),
    targets: NutritionTargets(
        mode: TargetMode.manual,
        kcal: target,
        macros: const Macros(protein: 150, carbs: 200, fat: 65)),
    entries: [_entry.copyWith(eaten: eaten)]);

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
        data: MediaQueryData(
            disableAnimations: true, textScaler: TextScaler.linear(textScale)),
        child: Directionality(
            textDirection: TextDirection.rtl,
            child: GlassScaffold(body: SingleChildScrollView(child: child)))));

void main() {
  testWidgets('planned food does not appear as eaten; plan remains accessible',
      (tester) async {
    await tester.pumpWidget(_app(TodaySummary(day: _day())));
    expect(find.text('0/2000'), findsOneWidget);
    await tester.tap(find.text(AppStrings.plannedDetails));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.plannedSummary(156, 30, 0, 4)), findsOneWidget);
    await tester.pumpWidget(_app(TodaySummary(day: _day(eaten: true))));
    expect(find.text('156/2000'), findsOneWidget);
    expect(find.text('1844'), findsOneWidget);
  });

  testWidgets('over-target and zero-target states remain finite',
      (tester) async {
    await tester
        .pumpWidget(_app(TodaySummary(day: _day(eaten: true, target: 100))));
    expect(find.text(AppStrings.aboveTarget), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    await tester.pumpWidget(_app(TodaySummary(day: _day(target: 0))));
    expect(tester.takeException(), isNull);
    for (final bar in tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator))) {
      expect(bar.value, inInclusiveRange(0, 1));
    }
  });

  testWidgets('entry checkbox and explicit edit action call the right handlers',
      (tester) async {
    var toggles = 0;
    var edits = 0;
    var deletes = 0;
    await tester.pumpWidget(_app(TodayEntryCard(
        entry: _entry,
        readOnly: false,
        onToggle: () => toggles++,
        onEdit: () => edits++,
        onDelete: () => deletes++)));
    await tester.tap(find.byType(Checkbox));
    expect(toggles, 1);
    await tester.tap(find.byTooltip(AppStrings.mealActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.edit));
    await tester.pumpAndSettle();
    expect(edits, 1);
    expect(deletes, 0);
  });

  testWidgets('deleting a day entry requires confirmation', (tester) async {
    var deletes = 0;
    await tester.pumpWidget(_app(TodayEntryCard(
      entry: _entry,
      readOnly: false,
      onToggle: () {},
      onEdit: () {},
      onDelete: () => deletes++,
    )));
    await tester.tap(find.byTooltip(AppStrings.mealActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.delete));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.deleteDayEntryTitle), findsOneWidget);
    expect(deletes, 0);
    await tester.tap(find.text(AppStrings.assistantCancel));
    await tester.pumpAndSettle();
    expect(deletes, 0);

    await tester.tap(find.byTooltip(AppStrings.mealActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.delete).last);
    await tester.pumpAndSettle();
    expect(deletes, 1);
  });

  testWidgets('history card exposes no controls until explicitly unlocked',
      (tester) async {
    var writes = 0;
    await tester.pumpWidget(_app(TodayEntryCard(
        entry: _entry,
        readOnly: true,
        onToggle: () => writes++,
        onEdit: () => writes++,
        onDelete: () => writes++)));
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.longPress(find.text(_entry.name));
    await tester.drag(find.byType(TodayEntryCard), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(writes, 0);
  });

  testWidgets('narrow RTL and large text fit without ambient effects',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(
        Column(children: [
          TodaySummary(day: _day()),
          TodayEntryCard(
              entry: _entry,
              readOnly: false,
              onToggle: () {},
              onEdit: () {},
              onDelete: () {}),
        ]),
        textScale: 1.7));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ReactiveAurora), findsOneWidget);
    expect(
        tester.widget<AuroraBackground>(find.byType(AuroraBackground)).animate,
        isFalse);
    expect(find.byType(BackdropFilter).evaluate().length, lessThanOrEqualTo(2));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
