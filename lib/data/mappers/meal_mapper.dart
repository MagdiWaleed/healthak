import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/meal/meal_definition.dart';
import '../../domain/meal/meal_entry.dart';
import '../../domain/nutrition/macros.dart';
import 'mapper_utils.dart';

class MealMapper {
  const MealMapper._();

  static MealDefinition fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) =>
      fromJson(snapshot.data() ?? const {}, id: snapshot.id);

  static Map<String, dynamic> toFirestore(MealDefinition meal, SetOptions? _) =>
      toJson(meal);

  static MealDefinition fromJson(Map<String, dynamic> json,
          {required String id}) =>
      MealDefinition(
        id: id,
        ownerUid: json['ownerUid'] as String? ?? '',
        name: json['name'] as String? ?? '',
        entries:
            mapList(json['entries']).map(entryFromJson).toList(growable: false),
        notes: json['notes'] as String?,
        imageUrl: json['imageUrl'] as String?,
        totalsCache: Macros.fromJson(stringMap(json['totalsCache'])),
        depth: intValue(json['depth']),
        leafCount: intValue(json['leafCount']),
        descendantMealIds: (json['descendantMealIds'] as List? ?? const [])
            .whereType<String>()
            .toSet(),
        origin:
            enumValue(MealOrigin.values, json['origin'], MealOrigin.authored),
        source: json['source'] is Map
            ? MealSource.fromJson(stringMap(json['source']))
            : null,
        publishedMarketMealId: json['publishedMarketMealId'] as String?,
        createdAt: dateValue(json['createdAt']),
        updatedAt: dateValue(json['updatedAt']),
      );

  static Map<String, dynamic> toJson(MealDefinition meal) => {
        'ownerUid': meal.ownerUid,
        'name': meal.name,
        'entries': meal.entries.map(entryToJson).toList(growable: false),
        'notes': meal.notes,
        'imageUrl': meal.imageUrl,
        'totalsCache': meal.totalsCache.toJson(),
        'depth': meal.depth,
        'leafCount': meal.leafCount,
        'descendantMealIds': meal.descendantMealIds.toList(growable: false),
        'origin': meal.origin.name,
        'source': meal.source == null ? null : sourceToJson(meal.source!),
        'publishedMarketMealId': meal.publishedMarketMealId,
        'createdAt': Timestamp.fromDate(meal.createdAt),
        'updatedAt': Timestamp.fromDate(meal.updatedAt),
      };

  static MealEntry entryFromJson(Map<String, dynamic> json) =>
      switch (json['type']) {
        'meal' => MealRefEntry(
            localId: json['localId'] as String? ?? '',
            order: intValue(json['order']),
            mealId: json['mealId'] as String? ?? '',
            name: json['name'] as String? ?? '',
            scale: doubleValue(json['scale'], 1),
            cachedTotals: Macros.fromJson(stringMap(json['cachedTotals'])),
            cachedAt:
                json['cachedAt'] == null ? null : dateValue(json['cachedAt']),
          ),
        _ => FoodEntry(
            localId: json['localId'] as String? ?? '',
            order: intValue(json['order']),
            foodId: json['foodId'] as String? ?? '',
            name: json['name'] as String? ?? '',
            per100: Macros.fromJson(stringMap(json['per100'])),
            grams: doubleValue(json['grams']),
          ),
      };

  static Map<String, dynamic> entryToJson(MealEntry entry) => switch (entry) {
        FoodEntry() => {
            'type': 'food',
            'localId': entry.localId,
            'order': entry.order,
            'foodId': entry.foodId,
            'name': entry.name,
            'per100': entry.per100.toJson(),
            'grams': entry.grams,
          },
        MealRefEntry() => {
            'type': 'meal',
            'localId': entry.localId,
            'order': entry.order,
            'mealId': entry.mealId,
            'name': entry.name,
            'scale': entry.scale,
            'cachedTotals': entry.cachedTotals.toJson(),
            'cachedAt': entry.cachedAt == null
                ? null
                : Timestamp.fromDate(entry.cachedAt!),
          },
      };

  static Map<String, dynamic> sourceToJson(MealSource source) => {
        'marketMealId': source.marketMealId,
        'authorUid': source.authorUid,
        'authorName': source.authorName,
        'version': source.version,
        'copiedAt': Timestamp.fromDate(source.copiedAt),
      };
}
