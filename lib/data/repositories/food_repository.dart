import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/food/food_item.dart';
import '../firestore_refs.dart';

const int kFoodPageSize = 30;

/// One stable catalog page. [nextCursor] is opaque to callers.
class FoodPage {
  final List<FoodItem> items;
  final DocumentSnapshot<FoodItem>? nextCursor;

  const FoodPage({required this.items, required this.nextCursor});

  bool get hasMore => nextCursor != null && items.length == kFoodPageSize;
}

/// Read-only access to the shared food catalog.
///
/// Foods are intentionally written only by the migration/admin path; client
/// writes are rejected by Firestore rules.
class FoodRepository {
  final FirestoreRefs _refs;

  FoodRepository({FirestoreRefs? refs}) : _refs = refs ?? FirestoreRefs();

  Future<FoodItem?> getById(String id) async =>
      (await _refs.foods.doc(id).get()).data();

  Future<FoodPage> list({
    String? category,
    String? searchToken,
    DocumentSnapshot<FoodItem>? startAfter,
  }) async {
    Query<FoodItem> query = _refs.foods.where('active', isEqualTo: true);
    final token = normalizeFoodSearchToken(searchToken);

    if (token != null) {
      query = query.where('searchTokens', arrayContains: token);
    }
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    query = query.orderBy('name').limit(kFoodPageSize);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snapshot = await query.get();
    return FoodPage(
      items: snapshot.docs
          .map((document) => document.data())
          .toList(growable: false),
      nextCursor: snapshot.docs.isEmpty ? null : snapshot.docs.last,
    );
  }

  Stream<FoodItem?> watchById(String id) =>
      _refs.foods.doc(id).snapshots().map((snapshot) => snapshot.data());
}

/// Matches the migration script's two-character minimum and Arabic fold.
String? normalizeFoodSearchToken(String? input) {
  final raw = input?.trim().toLowerCase();
  if (raw == null || raw.runes.length < 2) return null;

  return raw
      .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '')
      .replaceAll(RegExp(r'[\u0623\u0625\u0622]'), '\u0627')
      .replaceAll('\u0629', '\u0647')
      .replaceAll('\u0649', '\u064A');
}
