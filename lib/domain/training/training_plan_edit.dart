import 'exercise.dart';
import 'workout_plan_item.dart';

List<WorkoutPlanItem> reorderWorkoutDay(
    List<WorkoutPlanItem> plan, int weekday, int oldIndex, int newIndex) {
  final day = plan.where((e) => e.daysOfWeek.contains(weekday)).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  if (newIndex > oldIndex) newIndex--;
  final moved = day.removeAt(oldIndex);
  day.insert(newIndex, moved);
  final orders = {for (var i = 0; i < day.length; i++) day[i].id: i};
  return [
    for (final item in plan)
      if (orders.containsKey(item.id))
        item.copyWith(order: orders[item.id])
      else
        item
  ];
}

enum StarterTemplate { pushPullLegs, upperLower, fullBodyThree }

List<WorkoutPlanItem> expandStarterTemplate(
    StarterTemplate template, DateTime now, String Function() newId) {
  final days = switch (template) {
    StarterTemplate.pushPullLegs => <int, List<String>>{
        1: ['bench_press', 'overhead_press', 'triceps_pushdown'],
        3: ['lat_pulldown', 'barbell_row', 'barbell_curl'],
        5: ['barbell_squat', 'leg_press', 'calf_raise'],
      },
    StarterTemplate.upperLower => <int, List<String>>{
        1: ['bench_press', 'lat_pulldown', 'overhead_press'],
        2: ['barbell_squat', 'romanian_deadlift', 'calf_raise'],
        4: ['dumbbell_bench_press', 'barbell_row', 'lateral_raise'],
        5: ['leg_press', 'leg_curl', 'hip_thrust'],
      },
    StarterTemplate.fullBodyThree => <int, List<String>>{
        1: ['barbell_squat', 'bench_press', 'barbell_row'],
        3: ['leg_press', 'overhead_press', 'lat_pulldown'],
        5: ['romanian_deadlift', 'push_up', 'plank'],
      },
  };
  return [
    for (final entry in days.entries)
      for (var i = 0; i < entry.value.length; i++)
        if (exerciseById(entry.value[i]) case final exercise?)
          WorkoutPlanItem(
            id: newId(),
            exerciseId: exercise.id,
            nameAr: exercise.nameAr,
            muscle: exercise.muscle,
            sets: 3,
            reps: 10,
            daysOfWeek: {entry.key},
            order: i,
            createdAt: now,
            updatedAt: now,
          ),
  ];
}
