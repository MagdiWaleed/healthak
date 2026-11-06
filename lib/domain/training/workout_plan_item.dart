import 'exercise.dart';

class WorkoutPlanItem {
  final String id;
  final String exerciseId;
  final String nameAr;
  final MuscleGroup muscle;
  final int sets;
  final int reps;
  final Set<int> daysOfWeek;
  final int order;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkoutPlanItem({
    required this.id,
    required this.exerciseId,
    required this.nameAr,
    required this.muscle,
    required this.sets,
    required this.reps,
    required this.daysOfWeek,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.active = true,
  });

  static const Set<int> everyDay = {1, 2, 3, 4, 5, 6, 7};
  bool appliesTo(DateTime date) => active && daysOfWeek.contains(date.weekday);

  WorkoutPlanItem copyWith({
    String? exerciseId,
    String? nameAr,
    MuscleGroup? muscle,
    int? sets,
    int? reps,
    Set<int>? daysOfWeek,
    int? order,
    bool? active,
    DateTime? updatedAt,
  }) =>
      WorkoutPlanItem(
        id: id,
        exerciseId: exerciseId ?? this.exerciseId,
        nameAr: nameAr ?? this.nameAr,
        muscle: muscle ?? this.muscle,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        order: order ?? this.order,
        active: active ?? this.active,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// This persisted fingerprint must be deterministic across Dart isolates.
int workoutPlanVersionOf(Iterable<WorkoutPlanItem> items, int weekday) {
  final sorted = items
      .where((item) => item.active && item.daysOfWeek.contains(weekday))
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final canonical = sorted
      .map(
        (e) =>
            '${e.id.length}:${e.id}|${e.sets}|${e.reps}|${e.nameAr.length}:${e.nameAr}|${e.order}',
      )
      .join(';');
  var hash = 5381;
  for (final unit in canonical.codeUnits) {
    hash = ((hash << 5) + hash + unit) & 0xFFFFFFFF;
  }
  return hash;
}
