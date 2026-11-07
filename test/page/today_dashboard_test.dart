import 'dart:async';

import 'package:diet_app2/data/repositories/body_weight_repository.dart';
import 'package:diet_app2/data/repositories/day_repository.dart';
import 'package:diet_app2/data/repositories/training_day_repository.dart';
import 'package:diet_app2/data/repositories/workout_plan_repository.dart';
import 'package:diet_app2/domain/body/body_weight.dart';
import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/domain/training/training_day.dart';
import 'package:diet_app2/domain/training/workout_plan_item.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/today/today_controller.dart';
import 'package:diet_app2/page/today/today_dashboard.dart';
import 'package:diet_app2/page/deficit/deficit_mode_sheet.dart';
import 'package:diet_app2/page/me/me_tab.dart';
import 'package:diet_app2/page/training/training_controller.dart';
import 'package:diet_app2/service/session_controller.dart';
import 'package:diet_app2/ui/components/activity_rings.dart';
import 'package:diet_app2/ui/components/check_tile.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Session extends GetxController implements SessionController {
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

class _SharedTraining implements TrainingDayRepository {
  _SharedTraining(this.current);
  TrainingDay current;
  final snapshots = StreamController<TrainingDay?>.broadcast();
  @override
  Stream<TrainingDay?> watch(DateTime date) => snapshots.stream;
  @override
  Stream<List<TrainingDay>> watchRange(DateTime from, DateTime to) =>
      Stream.value([]);
  @override
  Future<TrainingDay> ensureTrainingDay(
      DateTime date, List<WorkoutPlanItem> plan) async {
    snapshots.add(current);
    return current;
  }

  @override
  Future<void> toggle(DateTime date, String localId) async {
    current = current.withToggled(localId, DateTime.now());
    snapshots.add(current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LiveDays implements DayRepository {
  @override
  Stream<DayLog?> watch(DateTime date) => Stream.value(_day());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LiveWeights implements BodyWeightRepository {
  @override
  Stream<List<BodyWeightEntry>> watchRange(DateTime from, DateTime to) =>
      Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingDays implements DayRepository {
  final calls = <({NutritionTargets targets, bool includeSchedule})>[];
  final updates = StreamController<DayLog?>.broadcast();
  @override
  Stream<DayLog?> watch(DateTime date) => updates.stream;
  @override
  Future<DayLog> ensureDay(
      {required DateTime date,
      required NutritionTargets targets,
      bool includeSchedule = true}) async {
    calls.add((targets: targets, includeSchedule: includeSchedule));
    final result = DayLog.empty(date, targets);
    updates.add(result);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietTraining implements TrainingDayRepository {
  @override
  Stream<TrainingDay?> watch(DateTime date) => Stream.value(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LiveToday extends TodayController {
  _LiveToday(_SharedTraining training)
      : super(
            uid: 'test',
            days: _LiveDays(),
            weights: _LiveWeights(),
            trainingDays: training,
            plans: _Plans(),
            session: _Session());
  @override
  // The fixture starts only the selected-day subscription.
  // ignore: must_call_super
  void onInit() {
    unawaited(selectDate(DateTime.now()));
  }
}

class _LivePlans implements WorkoutPlanRepository {
  final snapshots = StreamController<List<WorkoutPlanItem>>.broadcast();
  @override
  Stream<List<WorkoutPlanItem>> watchAll() => snapshots.stream;
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
  testWidgets('deficit dashboard shows budget and protein without other macros',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(_Training());
    final deficit = NutritionTargets.deficit(
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
        level: DeficitLevel.medium);
    final day = _day().copyWith(targets: deficit);
    await tester.pumpWidget(_app(
        TodayDashboard(day: day, controller: controller, readOnly: true),
        scale: 1.6));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.deficitEatLess(deficit.kcal.round())),
        findsOneWidget);
    expect(find.text(AppStrings.protein), findsWidgets);
    expect(find.text(AppStrings.carbs), findsNothing);
    expect(find.text(AppStrings.fat), findsNothing);
    controller.onClose();
  });

  testWidgets('deficit sheet previews each level at narrow large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final session = _Session();
    session.profile.value = UserProfile(
        uid: 'u',
        displayName: '',
        email: '',
        sex: Sex.male,
        birthYear: now.year - 30,
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        weeklyRateKg: 0,
        targets: NutritionTargets.empty,
        createdAt: now,
        updatedAt: now);
    Get.put<SessionController>(session);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          textScaler: TextScaler.linear(1.6), disableAnimations: true),
      child: Scaffold(body: DeficitModeSheet()),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final medium = NutritionTargets.deficit(
            weightKg: 80,
            heightCm: 180,
            ageYears: 30,
            sex: Sex.male,
            activity: ActivityLevel.moderate,
            level: DeficitLevel.medium)
        .kcal
        .round();
    expect(find.text(AppStrings.deficitPreview(2759, medium)), findsOneWidget);
    await tester.tap(find.text(AppStrings.deficitStrongPercent));
    await tester.pumpAndSettle();
    final strong = NutritionTargets.deficit(
            weightKg: 80,
            heightCm: 180,
            ageYears: 30,
            sex: Sex.male,
            activity: ActivityLevel.moderate,
            level: DeficitLevel.strong)
        .kcal
        .round();
    expect(find.text(AppStrings.deficitPreview(2759, strong)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await Get.delete<SessionController>();
  });

  testWidgets('Me shows active deficit level and budget', (tester) async {
    final now = DateTime.now();
    final session = _Session();
    session.profile.value = UserProfile(
        uid: 'u',
        displayName: '',
        email: '',
        sex: Sex.male,
        birthYear: now.year - 30,
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        weeklyRateKg: 0,
        targets: NutritionTargets.empty,
        deficit: DeficitMode(level: DeficitLevel.medium, startedAt: now),
        createdAt: now,
        updatedAt: now);
    Get.put<SessionController>(session);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          textScaler: TextScaler.linear(1.6), disableAnimations: true),
      child: Scaffold(body: MeTab()),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining(AppStrings.deficitLevel(15)), findsOneWidget);
    expect(
        find.textContaining(
            session.profile.value!.effectiveTargets.kcal.round().toString()),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await Get.delete<SessionController>();
  });
  test('Today materializes deficit without schedule and restores normal target',
      () async {
    final now = DateTime.now();
    const normal = NutritionTargets(
        mode: TargetMode.manual,
        kcal: 2100,
        macros: Macros(protein: 140, carbs: 200, fat: 70));
    final session = _Session();
    final base = UserProfile(
        uid: 'u',
        displayName: '',
        email: '',
        sex: Sex.male,
        birthYear: now.year - 30,
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        weeklyRateKg: 0,
        targets: normal,
        createdAt: now,
        updatedAt: now);
    session.profile.value = base.copyWith(
        deficit: DeficitMode(level: DeficitLevel.medium, startedAt: now));
    final days = _RecordingDays();
    final controller = TodayController(
        uid: 'u',
        days: days,
        weights: _LiveWeights(),
        trainingDays: _QuietTraining(),
        plans: _Plans(),
        session: session);
    await controller.selectDate(now);
    await Future<void>.delayed(Duration.zero);
    expect(days.calls.last.includeSchedule, isFalse);
    expect(days.calls.last.targets.mode, TargetMode.deficit);
    session.profile.value = base;
    await controller.selectDate(now);
    await Future<void>.delayed(Duration.zero);
    expect(days.calls.last.includeSchedule, isTrue);
    expect(days.calls.last.targets, normal);
    controller.onClose();
    await days.updates.close();
  });

  test('Today hides only uneaten scheduled entries in deficit mode', () {
    final now = DateTime.now();
    final session = _Session();
    session.profile.value = UserProfile(
        uid: 'u',
        displayName: '',
        email: '',
        sex: Sex.male,
        birthYear: now.year - 30,
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        weeklyRateKg: 0,
        targets: NutritionTargets.empty,
        deficit: DeficitMode(level: DeficitLevel.light, startedAt: now),
        createdAt: now,
        updatedAt: now);
    final controller = TodayController(
        uid: 'u',
        days: _Days(),
        weights: _Weights(),
        trainingDays: _Training(),
        plans: _Plans(),
        session: session);
    final day = DayLog.empty(now, session.profile.value!.effectiveTargets)
        .copyWith(entries: const [
      DayEntry(
          entryId: 'hidden',
          origin: DayEntryOrigin.scheduled,
          name: 'planned',
          slot: MealSlot.lunch,
          order: 0,
          items: []),
      DayEntry(
          entryId: 'shown',
          origin: DayEntryOrigin.scheduled,
          name: 'eaten',
          slot: MealSlot.lunch,
          order: 1,
          eaten: true,
          items: []),
      DayEntry(
          entryId: 'manual',
          origin: DayEntryOrigin.quickAdd,
          name: 'manual',
          slot: MealSlot.lunch,
          order: 2,
          items: []),
    ]);
    expect(controller.visibleEntries(day).map((e) => e.entryId),
        ['shown', 'manual']);
    session.profile.value = session.profile.value!.copyWith(clearDeficit: true);
    expect(controller.visibleEntries(day).length, 3);
    controller.onClose();
  });
  test('Today streak chip selects the largest current streak', () {
    final controller = _controller(_Training());
    controller.calorieStreak.value = 0;
    controller.trainingStreak.value = 1;
    controller.weighInStreak.value = 2;
    expect(controller.bestCurrentStreak.count, 2);
    expect(controller.bestCurrentStreak.name, AppStrings.streakWeighInName);
    controller.trainingStreak.value = 3;
    expect(controller.bestCurrentStreak.count, 3);
    expect(controller.bestCurrentStreak.name, AppStrings.streakTrainingName);
    controller.onClose();
  });
  testWidgets('Training toggle updates Today controller and rendered legend',
      (tester) async {
    final now = DateTime.now();
    final initial = TrainingDay(
        dateKey: DayLog.keyFor(now),
        date: now,
        materializedFromPlanVersion: 1,
        items: const [
          TrainingItem(
              localId: 'exercise',
              planItemId: 'plan',
              exerciseId: 'squat',
              nameAr: 'قرفصاء',
              muscle: MuscleGroup.legs,
              sets: 3,
              reps: 10,
              order: 0)
        ]);
    final shared = _SharedTraining(initial);
    final plans = _LivePlans();
    final today = _LiveToday(shared)..onInit();
    final training = TrainingController(
        uid: 'test', days: shared, plans: plans, clock: () => now)
      ..onInit();
    await tester.pump();
    plans.snapshots.add([]);
    await tester.pumpWidget(
        _app(TodayDashboard(day: _day(), controller: today, readOnly: true)));
    await tester.pump();
    expect(find.text('0/1'), findsOneWidget);
    await training.toggle('exercise');
    await tester.pump();
    expect(today.trainingDay.value?.items.single.done, isTrue);
    expect(find.text('1/1'), findsOneWidget);
    training.onClose();
    today.onClose();
    await shared.snapshots.close();
    await plans.snapshots.close();
  });

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
