import 'package:diet_app2/data/mappers/profile_mapper.dart';
import 'package:diet_app2/data/mappers/training_day_mapper.dart';
import 'package:diet_app2/data/mappers/workout_plan_mapper.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/domain/training/exercise.dart';
import 'package:diet_app2/domain/training/training_day.dart';
import 'package:diet_app2/domain/training/workout_plan_item.dart';
import 'package:diet_app2/domain/training/workout_templates.dart';
import 'package:flutter_test/flutter_test.dart';

const _home = {Equipment.pullUpBar, Equipment.dumbbells};
final _now = DateTime(2026, 11, 7);

WorkoutPlanItem _item(String id, Set<int> days, {double? loadKg}) =>
    WorkoutPlanItem(
      id: id,
      exerciseId: 'push_up',
      nameAr: 'ضغط أرضي',
      muscle: MuscleGroup.chest,
      sets: 3,
      reps: 10,
      daysOfWeek: days,
      order: 0,
      loadKg: loadKg,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  test('every library exercise has equipment tags and unique ids', () {
    final ids = kExerciseLibrary.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final e in kExerciseLibrary) {
      expect(e.needs, isNotEmpty, reason: e.id);
      expect(e.aliasesEn, isNotEmpty, reason: e.id);
    }
  });

  test('canDo: home kit allows pull-ups and dumbbells, not barbell bench', () {
    expect(canDo(exerciseById('pull_up')!, _home), isTrue);
    expect(canDo(exerciseById('dumbbell_floor_press')!, _home), isTrue);
    expect(canDo(exerciseById('push_up')!, const {}), isTrue);
    expect(canDo(exerciseById('bench_press')!, _home), isFalse);
    expect(canDo(exerciseById('dumbbell_bench_press')!, _home), isFalse,
        reason: 'needs a bench');
  });

  test('home templates only use home-capable exercises', () {
    for (final t
        in kWorkoutTemplates.where((t) => t.kind == TemplateKind.home)) {
      expect(t.fits(_home), isTrue, reason: t.id);
      expect(t.defaultDays.length, t.sessions.length, reason: t.id);
      for (final s in t.sessions) {
        for (final slot in s) {
          expect(exerciseById(slot.exerciseId), isNotNull,
              reason: '${t.id}/${slot.exerciseId}');
        }
      }
    }
    expect(
        kWorkoutTemplates
            .firstWhere((t) => t.id == 'gym_push_pull_legs')
            .fits(_home),
        isFalse);
  });

  test('applying a template only replaces the chosen weekdays', () {
    final plan = [
      _item('sat_only', {DateTime.saturday}),
      _item('mon_and_fri', {DateTime.monday, DateTime.friday}),
      _item('thu', {DateTime.thursday}),
    ];
    var n = 0;
    final incoming = expandTemplate(
        kWorkoutTemplates.first, const [1, 3, 5], _now, () => 'new${n++}');
    final result = applyTemplateToDays(plan, incoming, {1, 3, 5}, _now);
    final byId = {for (final i in result.plan) i.id: i};
    expect(byId['sat_only']!.daysOfWeek, {DateTime.saturday},
        reason: 'untouched day must stay');
    expect(byId['mon_and_fri'], isNull);
    expect(result.deletedIds, {'mon_and_fri'});
    expect(byId['thu']!.daysOfWeek, {DateTime.thursday});
    expect(result.plan.where((i) => i.id.startsWith('new')).length,
        incoming.length);
  });

  test('loadKg round-trips and is frozen into the training day', () {
    final item = _item('a', {DateTime.saturday}, loadKg: 12.5);
    final json = WorkoutPlanMapper.toJson(item);
    expect(WorkoutPlanMapper.fromJson(json, id: 'a').loadKg, 12.5);
    expect(WorkoutPlanMapper.toJson(_item('b', {6})).containsKey('loadKg'),
        isFalse);

    final day = TrainingDay.materialize(
        date: _now, plan: [item], existing: null, newId: () => 'x');
    expect(day.items.single.loadKg, 12.5);
    final back = TrainingDayMapper.itemFromJson(
        TrainingDayMapper.itemToJson(day.items.single));
    expect(back.loadKg, 12.5);
    expect(day.items.single.toggle(_now).loadKg, 12.5);
  });

  test('plan version is unchanged for items without a load', () {
    final noLoad = _item('a', {DateTime.saturday});
    final withLoad = _item('a', {DateTime.saturday}, loadKg: 10);
    expect(workoutPlanVersionOf([noLoad], DateTime.saturday),
        isNot(workoutPlanVersionOf([withLoad], DateTime.saturday)));
  });

  test('profile equipment round-trips; absent stays null', () {
    final base = UserProfile(
      uid: 'u',
      displayName: '',
      email: '',
      sex: Sex.male,
      birthYear: 1995,
      heightCm: 178,
      weightKg: 80,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.maintain,
      weeklyRateKg: 0,
      targets: NutritionTargets.empty,
      createdAt: _now,
      updatedAt: _now,
    );
    expect(
        ProfileMapper.fromJson(ProfileMapper.toJson(base), uid: 'u').equipment,
        isNull);
    final home = base.copyWith(equipment: _home);
    expect(
        ProfileMapper.fromJson(ProfileMapper.toCacheJson(home), uid: 'u')
            .equipment,
        _home);
  });
}
