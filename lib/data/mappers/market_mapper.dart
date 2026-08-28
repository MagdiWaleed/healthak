import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/day/day_log.dart';
import '../../domain/market/market_meal.dart';
import '../../domain/nutrition/macros.dart';
import 'mapper_utils.dart';

class MarketMapper {
  const MarketMapper._();

  static MarketMeal fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) =>
      fromJson(snapshot.data() ?? const {}, id: snapshot.id);

  static Map<String, dynamic> toFirestore(MarketMeal meal, SetOptions? _) =>
      toJson(meal);

  static MarketMeal fromJson(Map<String, dynamic> json, {required String id}) =>
      MarketMeal(
        id: id,
        authorUid: json['authorUid'] as String? ?? '',
        authorName: json['authorName'] as String? ?? '',
        name: json['name'] as String? ?? '',
        notes: json['notes'] as String?,
        imageUrl: json['imageUrl'] as String?,
        items: mapList(json['items'])
            .map(FrozenItem.fromJson)
            .toList(growable: false),
        groups: mapList(json['groups'])
            .map(MarketMealGroup.fromJson)
            .toList(growable: false),
        totals: Macros.fromJson(stringMap(json['totals'])),
        tags: (json['tags'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        language: json['language'] as String? ?? 'ar',
        copyCount: intValue(json['copyCount']),
        likeCount: intValue(json['likeCount']),
        status: enumValue(MarketMealStatus.values, json['status'],
            MarketMealStatus.published),
        version: intValue(json['version'], 1),
        createdAt: dateValue(json['createdAt']),
        updatedAt: dateValue(json['updatedAt']),
      );

  static Map<String, dynamic> toJson(MarketMeal meal) => {
        'authorUid': meal.authorUid,
        'authorName': meal.authorName,
        'name': meal.name,
        'notes': meal.notes,
        'imageUrl': meal.imageUrl,
        'items':
            meal.items.map((item) => item.toJson()).toList(growable: false),
        'groups':
            meal.groups.map((group) => group.toJson()).toList(growable: false),
        'totals': {...meal.totals.toJson(), 'kcal': meal.totals.kcal},
        'tags': meal.tags,
        'language': meal.language,
        'copyCount': meal.copyCount,
        'likeCount': meal.likeCount,
        'status': meal.status.name,
        'version': meal.version,
        'createdAt': Timestamp.fromDate(meal.createdAt),
        'updatedAt': Timestamp.fromDate(meal.updatedAt),
        'schemaVersion': 2,
      };
}
