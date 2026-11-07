import 'exercise.dart';
import 'workout_plan_item.dart';

enum TemplateKind { home, gym }

/// One exercise slot of a ready-made session.
class TemplateExercise {
  final String exerciseId;
  final int sets;
  final int reps;
  const TemplateExercise(this.exerciseId, this.sets, this.reps);
}

/// A ready-made weekly plan. Display text (title, description) lives in
/// l10n keyed by [id]; the domain only holds structure.
class WorkoutTemplate {
  final String id;
  final TemplateKind kind;
  final List<List<TemplateExercise>> sessions;

  /// Suggested weekdays (DateTime.monday = 1 ... sunday = 7), one per session.
  final List<int> defaultDays;
  final int minutesPerSession;

  const WorkoutTemplate({
    required this.id,
    required this.kind,
    required this.sessions,
    required this.defaultDays,
    required this.minutesPerSession,
  });

  /// Everything any of its exercises needs.
  Set<Equipment> get needs => {
        for (final session in sessions)
          for (final slot in session) ...?exerciseById(slot.exerciseId)?.needs,
      }..remove(Equipment.bodyweight);

  bool fits(Set<Equipment> have) => needs.difference(have).isEmpty;
}

const _homeFullBody = WorkoutTemplate(
  id: 'home_full_body_3',
  kind: TemplateKind.home,
  defaultDays: [DateTime.saturday, DateTime.monday, DateTime.wednesday],
  minutesPerSession: 40,
  sessions: [
    [
      TemplateExercise('dumbbell_squat', 3, 12),
      TemplateExercise('dumbbell_floor_press', 3, 10),
      TemplateExercise('pull_up', 3, 6),
      TemplateExercise('dumbbell_row', 3, 10),
      TemplateExercise('plank', 3, 30),
    ],
    [
      TemplateExercise('dumbbell_rdl', 3, 10),
      TemplateExercise('push_up', 3, 12),
      TemplateExercise('chin_up', 3, 6),
      TemplateExercise('dumbbell_shoulder_press', 3, 10),
      TemplateExercise('hanging_knee_raise', 3, 10),
    ],
    [
      TemplateExercise('dumbbell_lunge', 3, 10),
      TemplateExercise('decline_push_up', 3, 10),
      TemplateExercise('bent_over_dumbbell_row', 3, 10),
      TemplateExercise('lateral_raise', 3, 12),
      TemplateExercise('hammer_curl', 3, 12),
      TemplateExercise('overhead_triceps', 3, 12),
    ],
  ],
);

const _homeUpperLower = WorkoutTemplate(
  id: 'home_upper_lower_4',
  kind: TemplateKind.home,
  defaultDays: [
    DateTime.saturday,
    DateTime.sunday,
    DateTime.tuesday,
    DateTime.wednesday,
  ],
  minutesPerSession: 45,
  sessions: [
    [
      TemplateExercise('dumbbell_floor_press', 4, 8),
      TemplateExercise('pull_up', 4, 6),
      TemplateExercise('dumbbell_shoulder_press', 3, 10),
      TemplateExercise('dumbbell_row', 3, 10),
      TemplateExercise('dumbbell_curl', 3, 12),
      TemplateExercise('overhead_triceps', 3, 12),
    ],
    [
      TemplateExercise('goblet_squat', 4, 10),
      TemplateExercise('dumbbell_rdl', 4, 10),
      TemplateExercise('bulgarian_split_squat', 3, 10),
      TemplateExercise('calf_raise', 3, 15),
      TemplateExercise('hanging_knee_raise', 3, 12),
    ],
    [
      TemplateExercise('push_up', 4, 12),
      TemplateExercise('chin_up', 4, 6),
      TemplateExercise('arnold_press', 3, 10),
      TemplateExercise('bent_over_dumbbell_row', 3, 10),
      TemplateExercise('lateral_raise', 3, 12),
      TemplateExercise('hammer_curl', 3, 12),
    ],
    [
      TemplateExercise('dumbbell_squat', 4, 10),
      TemplateExercise('dumbbell_lunge', 3, 10),
      TemplateExercise('glute_bridge', 3, 15),
      TemplateExercise('step_up', 3, 10),
      TemplateExercise('plank', 3, 40),
    ],
  ],
);

const _bodyweightBeginner = WorkoutTemplate(
  id: 'bodyweight_beginner_3',
  kind: TemplateKind.home,
  defaultDays: [DateTime.saturday, DateTime.monday, DateTime.wednesday],
  minutesPerSession: 25,
  sessions: [
    [
      TemplateExercise('push_up', 3, 10),
      TemplateExercise('walking_lunge', 3, 10),
      TemplateExercise('glute_bridge', 3, 15),
      TemplateExercise('plank', 3, 30),
      TemplateExercise('mountain_climber', 3, 20),
    ],
    [
      TemplateExercise('pike_push_up', 3, 8),
      TemplateExercise('bulgarian_split_squat', 3, 8),
      TemplateExercise('leg_raise', 3, 12),
      TemplateExercise('side_plank', 3, 20),
      TemplateExercise('burpee', 3, 8),
    ],
    [
      TemplateExercise('push_up', 3, 10),
      TemplateExercise('step_up', 3, 10),
      TemplateExercise('calf_raise', 3, 15),
      TemplateExercise('bicycle_crunch', 3, 20),
      TemplateExercise('jump_squat', 3, 10),
    ],
  ],
);

const _gymPushPullLegs = WorkoutTemplate(
  id: 'gym_push_pull_legs',
  kind: TemplateKind.gym,
  defaultDays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
  minutesPerSession: 50,
  sessions: [
    [
      TemplateExercise('bench_press', 3, 10),
      TemplateExercise('overhead_press', 3, 10),
      TemplateExercise('triceps_pushdown', 3, 12),
    ],
    [
      TemplateExercise('lat_pulldown', 3, 10),
      TemplateExercise('barbell_row', 3, 10),
      TemplateExercise('barbell_curl', 3, 12),
    ],
    [
      TemplateExercise('barbell_squat', 3, 10),
      TemplateExercise('leg_press', 3, 12),
      TemplateExercise('calf_raise', 3, 15),
    ],
  ],
);

const _gymUpperLower = WorkoutTemplate(
  id: 'gym_upper_lower',
  kind: TemplateKind.gym,
  defaultDays: [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.thursday,
    DateTime.friday,
  ],
  minutesPerSession: 55,
  sessions: [
    [
      TemplateExercise('bench_press', 3, 8),
      TemplateExercise('lat_pulldown', 3, 10),
      TemplateExercise('overhead_press', 3, 10),
    ],
    [
      TemplateExercise('barbell_squat', 3, 8),
      TemplateExercise('romanian_deadlift', 3, 10),
      TemplateExercise('calf_raise', 3, 15),
    ],
    [
      TemplateExercise('dumbbell_bench_press', 3, 10),
      TemplateExercise('barbell_row', 3, 10),
      TemplateExercise('lateral_raise', 3, 12),
    ],
    [
      TemplateExercise('leg_press', 3, 12),
      TemplateExercise('leg_curl', 3, 12),
      TemplateExercise('hip_thrust', 3, 10),
    ],
  ],
);

const kWorkoutTemplates = <WorkoutTemplate>[
  _homeFullBody,
  _homeUpperLower,
  _bodyweightBeginner,
  _gymPushPullLegs,
  _gymUpperLower,
];

/// Plan items for [template] with session `i` on `days[i]`.
List<WorkoutPlanItem> expandTemplate(
  WorkoutTemplate template,
  List<int> days,
  DateTime now,
  String Function() newId,
) {
  assert(days.length == template.sessions.length);
  return [
    for (var s = 0; s < template.sessions.length; s++)
      for (var i = 0; i < template.sessions[s].length; i++)
        if (exerciseById(template.sessions[s][i].exerciseId) case final ex?)
          WorkoutPlanItem(
            id: newId(),
            exerciseId: ex.id,
            nameAr: ex.nameAr,
            muscle: ex.muscle,
            sets: template.sessions[s][i].sets,
            reps: template.sessions[s][i].reps,
            daysOfWeek: {days[s]},
            order: i,
            createdAt: now,
            updatedAt: now,
          ),
  ];
}

/// Merges [incoming] into [plan], replacing ONLY the weekdays in [days].
///
/// Existing items lose those weekdays; an item left with no weekday is
/// deleted. Every other day is untouched -- applying a template must never
/// silently empty a day the user did not pick.
({List<WorkoutPlanItem> plan, Set<String> deletedIds}) applyTemplateToDays(
  List<WorkoutPlanItem> plan,
  List<WorkoutPlanItem> incoming,
  Set<int> days,
  DateTime now,
) {
  final kept = <WorkoutPlanItem>[];
  final deleted = <String>{};
  for (final item in plan) {
    if (item.daysOfWeek.intersection(days).isEmpty) {
      kept.add(item);
      continue;
    }
    final remaining = item.daysOfWeek.difference(days);
    if (remaining.isEmpty) {
      deleted.add(item.id);
    } else {
      kept.add(item.copyWith(daysOfWeek: remaining, updatedAt: now));
    }
  }
  return (plan: [...kept, ...incoming], deletedIds: deleted);
}
