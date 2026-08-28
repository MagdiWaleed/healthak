import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/food/food_item.dart';
import '../../domain/nutrition/macros.dart';

/// The sole Firestore serialization boundary for [FoodItem].
class FoodMapper {
  const FoodMapper._();

  static FoodItem fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) =>
      fromJson(snapshot.data() ?? const {}, id: snapshot.id);

  static Map<String, dynamic> toFirestore(FoodItem food, SetOptions? _) =>
      toJson(food);

  static FoodItem fromJson(Map<String, dynamic> json, {required String id}) {
    final per100 = Macros.fromJson(_map(json['per100']));
    return FoodItem(
      id: id,
      name: json['name'] as String? ?? '',
      nameNormalized: json['nameNormalized'] as String? ?? '',
      category: json['category'] as String?,
      per100: per100,
      // The stored field only supports Firestore ordering. Keep its value from
      // becoming a second source of nutritional truth after a malformed write.
      kcalPer100: per100.kcal,
      micros: _micros(json['micros']),
      imageUrl: json['imageUrl'] as String?,
      pricePer100: _double(json['pricePer100']),
      note: json['note'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  static Map<String, dynamic> toJson(FoodItem food) => {
        'name': food.name,
        'nameNormalized': food.nameNormalized,
        'category': food.category,
        'active': food.active,
        'per100': food.per100.toJson(),
        // Denormalized only for Firestore sorting. [FoodItem.per100] is truth.
        'kcalPer100': food.per100.kcal,
        'micros': food.micros,
        'imageUrl': food.imageUrl,
        'pricePer100': food.pricePer100,
        'note': food.note,
      };

  static Map<String, dynamic> _map(Object? value) =>
      (value as Map?)?.cast<String, dynamic>() ?? const {};

  static Map<String, num>? _micros(Object? value) {
    final map = value as Map?;
    if (map == null) return null;

    return {
      for (final entry in map.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: entry.value as num,
    };
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
