import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/training/exercise.dart';
import '../../domain/training/workout_plan_item.dart';
import 'mapper_utils.dart';

class WorkoutPlanMapper {
  const WorkoutPlanMapper._();
  static WorkoutPlanItem fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) =>
      fromJson(snapshot.data() ?? const {}, id: snapshot.id);
  static Map<String, dynamic> toFirestore(
    WorkoutPlanItem item,
    SetOptions? _,
  ) =>
      toJson(item);
  static WorkoutPlanItem fromJson(
    Map<String, dynamic> json, {
    required String id,
  }) =>
      WorkoutPlanItem(
        id: id,
        exerciseId: json['exerciseId'] as String? ?? '',
        nameAr: json['nameAr'] as String? ?? '',
        muscle:
            enumValue(MuscleGroup.values, json['muscle'], MuscleGroup.fullBody),
        sets: intValue(json['sets']),
        reps: intValue(json['reps']),
        daysOfWeek:
            (json['daysOfWeek'] as List? ?? const []).map(intValue).toSet(),
        order: intValue(json['order']),
        active: json['active'] as bool? ?? true,
        createdAt: dateValue(json['createdAt']),
        updatedAt: dateValue(json['updatedAt']),
      );
  static Map<String, dynamic> toJson(WorkoutPlanItem item) => {
        'exerciseId': item.exerciseId,
        'nameAr': item.nameAr,
        'muscle': item.muscle.name,
        'sets': item.sets,
        'reps': item.reps,
        'daysOfWeek': item.daysOfWeek.toList()..sort(),
        'order': item.order,
        'active': item.active,
        'createdAt': Timestamp.fromDate(item.createdAt),
        'updatedAt': Timestamp.fromDate(item.updatedAt),
      };
}
