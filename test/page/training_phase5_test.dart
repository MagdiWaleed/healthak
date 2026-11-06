import 'dart:async';

import 'package:diet_app2/data/repositories/training_day_repository.dart';
import 'package:diet_app2/data/repositories/workout_plan_repository.dart';
import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/domain/training/training_day.dart';
import 'package:diet_app2/domain/training/workout_plan_item.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/training/exercise_picker_sheet.dart';
import 'package:diet_app2/page/training/plan_editor_screen.dart';
import 'package:diet_app2/page/training/training_controller.dart';
import 'package:diet_app2/page/training/training_tab.dart';
import 'package:diet_app2/ui/components/check_tile.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

final _now = DateTime(2026, 11, 7);
TrainingDay _day(DateTime date, {bool done = false}) => TrainingDay(
      dateKey: DayLog.keyFor(date),
      date: date,
      materializedFromPlanVersion: 1,
      items: [
        TrainingItem(
            localId: 'one',
            planItemId: 'plan',
            exerciseId: 'bench_press',
            nameAr: 'ضغط بالبار',
            muscle: MuscleGroup.chest,
            sets: 3,
            reps: 10,
            order: 0,
            done: done)
      ],
    );

class _TrainingRepo implements TrainingDayRepository {
  final stream = StreamController<TrainingDay?>.broadcast();
  TrainingDay? current;
  int toggles = 0;
  _TrainingRepo(this.current);
  @override
  Stream<TrainingDay?> watch(DateTime date) => stream.stream;
  @override
  Stream<List<TrainingDay>> watchRange(DateTime from, DateTime to) =>
      Stream.value([]);
  @override
  Future<TrainingDay> ensureTrainingDay(
      DateTime date, List<WorkoutPlanItem> plan) async {
    final value = current ?? _day(date);
    stream.add(value);
    return value;
  }

  @override
  Future<void> toggle(DateTime date, String localId) async {
    toggles++;
    current = current!.withToggled(localId, _now);
    stream.add(current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlanRepo implements WorkoutPlanRepository {
  @override
  Stream<List<WorkoutPlanItem>> watchAll() => Stream.value([]);
  @override
  Future<List<WorkoutPlanItem>> getAll() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticController extends TrainingController {
  _StaticController()
      : super(
            uid: 'test',
            days: _TrainingRepo(null),
            plans: _PlanRepo(),
            clock: () => _now);
  // This fixture supplies snapshots directly and intentionally skips subscriptions.
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  setUp(() => Get.reset());
  tearDown(() => Get.reset());

  test('controller toggles once and celebrates complete day once', () async {
    final repo = _TrainingRepo(_day(_now));
    final controller = Get.put(TrainingController(
        uid: 'test', days: repo, plans: _PlanRepo(), clock: () => _now));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(controller.day.value?.items.length, 1);
    await controller.toggle('one');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.toggles, 1);
    expect(controller.celebration.value, 1);
    await controller.toggle('one');
    await controller.toggle('one');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(controller.celebration.value, 1);
    await repo.stream.close();
  });

  testWidgets('checklist renders and historical day is read only',
      (tester) async {
    final controller = Get.put<TrainingController>(_StaticController());
    controller.day.value = _day(_now);
    controller.loading.value = false;
    await tester.pumpWidget(GetMaterialApp(
        theme: AppTheme.dark,
        home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: TrainingTab()))));
    await tester.pump();
    expect(find.byType(CheckTile), findsOneWidget);
    controller.selectedDate.value = DateTime(2026, 11, 6);
    controller.day.value = _day(DateTime(2026, 11, 6));
    await tester.pump();
    expect(find.text(AppStrings.historyReadOnly), findsOneWidget);
    expect(tester.widget<CheckTile>(find.byType(CheckTile)).enabled, isFalse);
  });

  testWidgets('picker finds Arabic variants', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: ExercisePickerSheet())));
    await tester.enterText(find.byType(TextField).first, 'ضغط ارضي');
    await tester.pump();
    expect(find.text('ضغط أرضي'), findsOneWidget);
  });

  testWidgets('plan editor opens with weekday tabs and save', (tester) async {
    Get.put(PlanEditorController(uid: 'test', repository: _PlanRepo()));
    await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.dark, home: const PlanEditorScreen()));
    await tester.pump();
    expect(find.text(AppStrings.trainingPlanEdit), findsOneWidget);
    expect(find.text(AppStrings.trainingTemplates), findsOneWidget);
  });
}
