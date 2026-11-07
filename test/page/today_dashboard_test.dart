import 'package:diet_app2/data/repositories/body_weight_repository.dart';
import 'package:diet_app2/data/repositories/day_repository.dart';
import 'package:diet_app2/data/repositories/training_day_repository.dart';
import 'package:diet_app2/data/repositories/workout_plan_repository.dart';
import 'package:diet_app2/domain/body/body_weight.dart';
import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/domain/training/training_day.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/today/today_controller.dart';
import 'package:diet_app2/page/today/today_dashboard.dart';
import 'package:diet_app2/service/session_controller.dart';
import 'package:diet_app2/ui/components/activity_rings.dart';
import 'package:diet_app2/ui/components/check_tile.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Session implements SessionController {
  @override
  final profile = Rxn();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Days implements DayRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Weights implements BodyWeightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Plans implements WorkoutPlanRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Training implements TrainingDayRepository {
  int toggles = 0;
  @override
  Future<void> toggle(DateTime date, String localId) async => toggles++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TodayController _controller(_Training training) => TodayController(
    uid: 'test',
    days: _Days(),
    weights: _Weights(),
    trainingDays: training,
    plans: _Plans(),
    session: _Session());

DayLog _day({bool eaten = false}) => DayLog(
        dateKey: '2026-11-07',
        date: DateTime(2026, 11, 7),
        targets: const NutritionTargets(
            mode: TargetMode.manual,
            kcal: 100,
            macros: Macros(protein: 20, carbs: 20, fat: 10)),
        entries: [
          DayEntry(
              entryId: 'meal',
              origin: DayEntryOrigin.quickAdd,
              name: 'وجبة',
              slot: MealSlot.lunch,
              order: 0,
              eaten: eaten,
              items: const [
                FrozenItem(
                    foodId: 'food',
                    name: 'طعام',
                    per100: Macros(protein: 25, carbs: 0, fat: 0),
                    grams: 100)
              ])
        ]);

TrainingDay _trainingDay({bool done = false, bool rest = false}) => TrainingDay(
    dateKey: '2026-11-07',
    date: DateTime(2026, 11, 7),
    materializedFromPlanVersion: 1,
    items: rest
        ? const []
        : [
            TrainingItem(
                localId: 'exercise',
                planItemId: 'plan',
                exerciseId: 'squat',
                nameAr: 'قرفصاء',
                muscle: MuscleGroup.legs,
                sets: 3,
                reps: 10,
                order: 0,
                done: done)
          ]);

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
        data: MediaQueryData(
            disableAnimations: true, textScaler: TextScaler.linear(scale)),
        child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: SingleChildScrollView(child: child)))));

void main() {
  testWidgets('rings, weight and workout render and checks respect readOnly',
      (tester) async {
    final repo = _Training();
    final controller = _controller(repo);
    controller.trainingDay.value = _trainingDay();
    final now = DateTime(2026, 11, 7);
    controller.weightToday.value = BodyWeightEntry(
        dateKey: '2026-11-07',
        date: now,
        kg: 75,
        createdAt: now,
        updatedAt: now);
    await tester.pumpWidget(_app(
        TodayDashboard(day: _day(), controller: controller, readOnly: true)));
    expect(find.byType(ActivityRings), findsOneWidget);
    expect(find.text('75.0 ${AppStrings.kg}'), findsOneWidget);
    expect(find.byType(CheckTile), findsOneWidget);
    await tester.ensureVisible(find.byType(CheckTile));
    await tester.tap(find.text('قرفصاء'));
    expect(repo.toggles, 0);
    await tester.pumpWidget(_app(
        TodayDashboard(day: _day(), controller: controller, readOnly: false)));
    controller.selectedDate.value = controller.today.value;
    await tester.ensureVisible(find.byType(CheckTile));
    await tester.tap(find.text('قرفصاء'));
    await tester.pump();
    expect(repo.toggles, 1);
  });

  testWidgets('rest day and narrow large text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(_Training());
    controller.trainingDay.value = _trainingDay(rest: true);
    await tester.pumpWidget(_app(
        TodayDashboard(day: _day(), controller: controller, readOnly: true),
        scale: 1.6));
    expect(find.text(AppStrings.restDay), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  test('completed ring fires once per date', () {
    final controller = _controller(_Training());
    controller.day.value = _day(eaten: true);
    expect(controller.checkRingCelebration(), isTrue);
    expect(controller.checkRingCelebration(), isFalse);
    expect(controller.goalCelebration.value, 1);
  });
}
