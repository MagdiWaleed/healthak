import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/body/body_weight.dart';
import 'mapper_utils.dart';

class BodyWeightMapper {
  const BodyWeightMapper._();
  static BodyWeightEntry fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) =>
      fromJson(snapshot.data() ?? const {}, dateKey: snapshot.id);
  static Map<String, dynamic> toFirestore(
    BodyWeightEntry entry,
    SetOptions? _,
  ) =>
      toJson(entry);
  static BodyWeightEntry fromJson(
    Map<String, dynamic> json, {
    required String dateKey,
  }) =>
      BodyWeightEntry(
        dateKey: dateKey,
        date: dateValue(json['date']),
        kg: doubleValue(json['kg']),
        createdAt: dateValue(json['createdAt']),
        updatedAt: dateValue(json['updatedAt']),
      );
  static Map<String, dynamic> toJson(BodyWeightEntry entry) => {
        'dateKey': entry.dateKey,
        'date': Timestamp.fromDate(entry.date),
        'kg': entry.kg,
        'createdAt': Timestamp.fromDate(entry.createdAt),
        'updatedAt': Timestamp.fromDate(entry.updatedAt),
      };
}
