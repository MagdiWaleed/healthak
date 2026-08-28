import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic> stringMap(Object? value) =>
    (value as Map?)?.cast<String, dynamic>() ?? const {};

List<Map<String, dynamic>> mapList(Object? value) =>
    (value as List?)?.map(stringMap).toList(growable: false) ?? const [];

double doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

DateTime dateValue(Object? value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value) ??
        (fallback ?? DateTime.fromMillisecondsSinceEpoch(0));
  }
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

T enumValue<T extends Enum>(List<T> values, Object? value, T fallback) =>
    values.where((item) => item.name == value).firstOrNull ?? fallback;

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
