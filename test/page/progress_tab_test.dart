import 'package:diet_app2/data/repositories/body_weight_repository.dart';
import 'package:diet_app2/data/repositories/day_repository.dart';
import 'package:diet_app2/data/repositories/training_day_repository.dart';
import 'package:diet_app2/domain/body/body_weight.dart';
import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/domain/training/training_day.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/progress/progress_controller.dart';
import 'package:diet_app2/page/progress/progress_tab.dart';
import 'package:diet_app2/service/session_controller.dart';
import 'package:diet_app2/ui/components/weight_chart.dart';
import 'package:diet_app2/ui/glass/glass_card.dart';
import 'package:diet_app2/ui/theme/app_colors.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Days implements DayRepository {
  _Days(this.data);
  final List<DayLog> data;
  @override
  Stream<List<DayLog>> watchRange(DateTime from, DateTime to) =>
      Stream.value(data);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Training implements TrainingDayRepository {
  _Training(this.data);
  final List<TrainingDay> data;
  @override
  Stream<List<TrainingDay>> watchRange(DateTime from, DateTime to) =>
      Stream.value(data);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Weights implements BodyWeightRepository {
  _Weights(this.data);
  final List<BodyWeightEntry> data;
  @override
  Stream<List<BodyWeightEntry>> watchRange(DateTime from, DateTime to) =>
      Stream.value(data);
  @override
  Stream<List<BodyWeightEntry>> watchLatest(int limit) =>
      Stream.value(data.reversed.take(limit).toList());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements SessionController {
  @override
  final profile = Rxn<UserProfile>();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BodyWeightEntry _weight(DateTime date, double kg) => BodyWeightEntry(
      dateKey: DayLog.keyFor(date),
      date: date,
      kg: kg,
      createdAt: date,
      updatedAt: date,
    );

DayLog _day(DateTime date, {bool eaten = true}) => DayLog(
      dateKey: DayLog.keyFor(date),
      date: date,
      targets: NutritionTargets.manual(kcal: 100, macros: Macros.zero),
      entries: [
        DayEntry(
          entryId: 'meal',
          origin: DayEntryOrigin.oneShot,
          name: 'وجبة',
          slot: MealSlot.lunch,
          order: 0,
          eaten: eaten,
          items: const [
            FrozenItem(
              foodId: 'food',
              name: 'طعام',
              per100: Macros(protein: 25, carbs: 0, fat: 0),
              grams: 100,
            ),
          ],
        ),
      ],
    );

TrainingDay _trainingDay(DateTime date) => TrainingDay(
      dateKey: DayLog.keyFor(date),
      date: date,
      materializedFromPlanVersion: 1,
      items: const [
        TrainingItem(
          localId: 'squat',
          planItemId: 'plan',
          exerciseId: 'squat',
          nameAr: 'قرفصاء',
          muscle: MuscleGroup.legs,
          sets: 3,
          reps: 10,
          order: 0,
          done: true,
        ),
      ],
    );

ProgressController _controller({
  List<DayLog> days = const [],
  List<TrainingDay> training = const [],
  List<BodyWeightEntry> weights = const [],
}) =>
    ProgressController(
      uid: 'test',
      days: _Days(days),
      trainingDays: _Training(training),
      weights: _Weights(weights),
      session: _Session(),
      clock: () => DateTime(2026, 11, 7),
    );

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('controller derives range, streaks and recap from fake repositories',
      () async {
    final today = DateTime(2026, 11, 7);
    final controller = _controller(
      days: [_day(today), _day(DateTime(2026, 11, 6), eaten: false)],
      training: [_trainingDay(today)],
      weights: [
        _weight(DateTime(2026, 10, 25), 80),
        _weight(DateTime(2026, 11, 6), 79),
        _weight(today, 78),
      ],
    );
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visibleWeights.length, 3);
    expect(controller.calorieStreak.current, 1);
    expect(controller.trainingStreak.current, 1);
    expect(controller.weighInStreak.current, 2);
    expect(controller.recap.avgKcal, 100);
    expect(controller.recap.sessionsDone, 1);
    expect(controller.rangeDeltaKg, lessThan(0));
    controller.selectRange(7);
    expect(controller.visibleWeights.length, 2);
    controller.onClose();
  });

  testWidgets('progress tab shows empty and populated states', (tester) async {
    Get.put(_controller());
    await tester.pumpWidget(_app(const ProgressTab()));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.progressNoWeights), findsWidgets);
    await tester.scrollUntilVisible(
        find.text(AppStrings.progressWeeklyRecap), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(AppStrings.progressWeeklyRecap), findsOneWidget);
    await Get.delete<ProgressController>(force: true);
    await tester.pumpWidget(const SizedBox.shrink());

    Get.put(_controller(weights: [_weight(DateTime(2026, 11, 7), 78)]));
    await tester.pumpWidget(_app(const ProgressTab()));
    await tester.pumpAndSettle();
    expect(find.byType(WeightChart), findsOneWidget);
    await tester.scrollUntilVisible(find.text('78.0 كجم'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('78.0 كجم'), findsWidgets);
  });

  testWidgets('progress tab fits a narrow RTL screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    Get.put(_controller(weights: [_weight(DateTime(2026, 11, 7), 78)]));
    await tester.pumpWidget(_app(const ProgressTab()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(AppStrings.history), 220,
        scrollable: find.byType(Scrollable).first);
    final error = tester.takeException();
    expect(error, isNull);
  });

  testWidgets('weekly recap keeps seven labeled bars with one logged day',
      (tester) async {
    final today = DateTime(2026, 11, 7);
    Get.put(_controller(days: [_day(today)]));
    await tester.pumpWidget(_app(const ProgressTab()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(BarChart), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.length, 7);
    expect(chart.data.barGroups.map((group) => group.x),
        orderedEquals([0, 1, 2, 3, 4, 5, 6]));
    expect(chart.data.barGroups.last.barRods.single.toY,
        greaterThan(chart.data.barGroups.first.barRods.single.toY));
    expect(chart.data.extraLinesData.horizontalLines.single.dashArray, [5, 4]);
    for (var i = 0; i < 7; i++) {
      final weekday = DateTime(2026, 11, 1 + i).weekday;
      expect(find.text(AppStrings.weekdayShort[weekday - 1]), findsWidgets);
    }
  });

  testWidgets('zero streak uses muted flame and start wording', (tester) async {
    Get.put(_controller());
    await tester.pumpWidget(_app(const ProgressTab()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(AppStrings.progressStreaks), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.startStreak), findsNWidgets(3));
    final flames = tester
        .widgetList<Icon>(find.byIcon(Icons.local_fire_department_rounded));
    expect(flames.every((icon) => icon.color == AppPalette.muted), isTrue);
  });

  testWidgets('active streak uses coral flame', (tester) async {
    Get.put(_controller(training: [_trainingDay(DateTime(2026, 11, 7))]));
    await tester.pumpWidget(_app(const ProgressTab()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text(AppStrings.progressTrainingStreak), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final card = find
        .ancestor(
            of: find.text(AppStrings.progressTrainingStreak),
            matching: find.byType(GlassCard))
        .first;
    expect(
        tester
            .widget<Icon>(find.descendant(
                of: card,
                matching: find.byIcon(Icons.local_fire_department_rounded)))
            .color,
        AppPalette.coral);
  });

  for (final count in [1, 2, 90]) {
    testWidgets('weight chart builds for $count points', (tester) async {
      final end = DateTime(2026, 11, 7);
      final entries = [
        for (var i = 0; i < count; i++)
          _weight(DateTime(2026, 11, 7 - count + i + 1), 80 - i * .05),
      ];
      await tester.pumpWidget(_app(Center(
        child:
            WeightChart(entries: entries, days: 90, endDate: end, goalKg: 75),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
