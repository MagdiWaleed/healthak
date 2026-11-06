import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/training/exercise.dart';
import '../../domain/training/training_day.dart';
import 'mapper_utils.dart';

class TrainingDayMapper {
  const TrainingDayMapper._();
  static TrainingDay fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) =>
      fromJson(snapshot.data() ?? const {}, dateKey: snapshot.id);
  static Map<String, dynamic> toFirestore(TrainingDay day, SetOptions? _) =>
      toJson(day);
  static TrainingDay fromJson(
    Map<String, dynamic> json, {
    required String dateKey,
  }) =>
      TrainingDay(
        dateKey: dateKey,
        date: dateValue(json['date']),
        items: mapList(json['items']).map(itemFromJson).toList(growable: false),
        materializedFromPlanVersion:
            intValue(json['materializedFromPlanVersion']),
      );
  static Map<String, dynamic> toJson(TrainingDay day) => {
        'dateKey': day.dateKey,
        'date': Timestamp.fromDate(day.date),
        'items': day.items.map(itemToJson).toList(growable: false),
        'materializedFromPlanVersion': day.materializedFromPlanVersion,
      };
  static TrainingItem itemFromJson(Map<String, dynamic> json) => TrainingItem(
        localId: json['localId'] as String? ?? '',
        planItemId: json['planItemId'] as String?,
        exerciseId: json['exerciseId'] as String? ?? '',
        nameAr: json['nameAr'] as String? ?? '',
        muscle:
            enumValue(MuscleGroup.values, json['muscle'], MuscleGroup.fullBody),
        sets: intValue(json['sets']),
        reps: intValue(json['reps']),
        order: intValue(json['order']),
        done: json['done'] as bool? ?? false,
        doneAt: json['doneAt'] == null ? null : dateValue(json['doneAt']),
      );
  static Map<String, dynamic> itemToJson(TrainingItem item) => {
        'localId': item.localId,
        'planItemId': item.planItemId,
        'exerciseId': item.exerciseId,
        'nameAr': item.nameAr,
        'muscle': item.muscle.name,
        'sets': item.sets,
        'reps': item.reps,
        'order': item.order,
        'done': item.done,
        'doneAt': item.doneAt == null ? null : Timestamp.fromDate(item.doneAt!),
      };
}
