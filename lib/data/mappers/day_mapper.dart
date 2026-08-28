import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/day/day_log.dart';
import '../../domain/nutrition/energy.dart';
import 'mapper_utils.dart';

class DayMapper {
  const DayMapper._();

  static DayLog fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) =>
      fromJson(snapshot.data() ?? const {}, dateKey: snapshot.id);

  static Map<String, dynamic> toFirestore(DayLog day, SetOptions? _) =>
      toJson(day);

  static DayLog fromJson(Map<String, dynamic> json,
          {required String dateKey}) =>
      DayLog(
        dateKey: dateKey,
        date: dateValue(json['date']),
        tzOffsetMinutes: intValue(json['tzOffsetMinutes']),
        targets: NutritionTargets.fromJson(stringMap(json['targets'])),
        entries:
            mapList(json['entries']).map(entryFromJson).toList(growable: false),
        materializedFromScheduleVersion:
            intValue(json['materializedFromScheduleVersion']),
      );

  static Map<String, dynamic> toJson(DayLog day) => {
        'dateKey': day.dateKey,
        'date': Timestamp.fromDate(day.date),
        'tzOffsetMinutes': day.tzOffsetMinutes,
        'targets': day.targets.toJson(),
        'entries': day.entries.map(entryToJson).toList(growable: false),
        'materializedFromScheduleVersion': day.materializedFromScheduleVersion,
      };

  static DayEntry entryFromJson(Map<String, dynamic> json) => DayEntry(
        entryId: json['entryId'] as String? ?? '',
        origin: enumValue(
            DayEntryOrigin.values, json['origin'], DayEntryOrigin.oneShot),
        scheduleItemId: json['scheduleItemId'] as String?,
        sourceMealId: json['sourceMealId'] as String?,
        name: json['name'] as String? ?? '',
        slot: enumValue(MealSlot.values, json['slot'], MealSlot.snack),
        order: intValue(json['order']),
        eaten: json['eaten'] as bool? ?? false,
        eatenAt: json['eatenAt'] == null ? null : dateValue(json['eatenAt']),
        items: mapList(json['items'])
            .map(FrozenItem.fromJson)
            .toList(growable: false),
      );

  static Map<String, dynamic> entryToJson(DayEntry entry) => {
        'entryId': entry.entryId,
        'origin': entry.origin.name,
        'scheduleItemId': entry.scheduleItemId,
        'sourceMealId': entry.sourceMealId,
        'name': entry.name,
        'slot': entry.slot.name,
        'order': entry.order,
        'eaten': entry.eaten,
        'eatenAt':
            entry.eatenAt == null ? null : Timestamp.fromDate(entry.eatenAt!),
        'items':
            entry.items.map((item) => item.toJson()).toList(growable: false),
      };
}
