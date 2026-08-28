import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/day/day_log.dart';
import '../../domain/schedule/schedule_item.dart';
import 'mapper_utils.dart';

class ScheduleMapper {
  const ScheduleMapper._();

  static ScheduleItem fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) =>
      fromJson(snapshot.data() ?? const {}, id: snapshot.id);

  static Map<String, dynamic> toFirestore(ScheduleItem item, SetOptions? _) =>
      toJson(item);

  static ScheduleItem fromJson(Map<String, dynamic> json,
          {required String id}) =>
      ScheduleItem(
        id: id,
        mealId: json['mealId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        snapshot: mapList(json['snapshot'])
            .map(FrozenItem.fromJson)
            .toList(growable: false),
        slot: enumValue(MealSlot.values, json['slot'], MealSlot.snack),
        order: intValue(json['order']),
        daysOfWeek:
            (json['daysOfWeek'] as List? ?? const []).map(intValue).toSet(),
        active: json['active'] as bool? ?? true,
        createdAt: dateValue(json['createdAt']),
        updatedAt: dateValue(json['updatedAt']),
      );

  static Map<String, dynamic> toJson(ScheduleItem item) => {
        'mealId': item.mealId,
        'name': item.name,
        'snapshot':
            item.snapshot.map((food) => food.toJson()).toList(growable: false),
        'slot': item.slot.name,
        'order': item.order,
        'daysOfWeek': item.daysOfWeek.toList(growable: false),
        'active': item.active,
        'createdAt': Timestamp.fromDate(item.createdAt),
        'updatedAt': Timestamp.fromDate(item.updatedAt),
      };
}
