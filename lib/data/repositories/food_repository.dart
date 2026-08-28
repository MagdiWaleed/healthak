import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/food/food_item.dart';
import '../firestore_refs.dart';
import '../mappers/food_mapper.dart';

const int kFoodPageSize = 30;

/// One stable catalog page. [nextCursor] is opaque to callers.
class FoodPage {
  final List<FoodItem> items;
  final DocumentSnapshot<FoodItem>? nextCursor;

  const FoodPage({required this.items, required this.nextCursor});

  bool get hasMore => nextCursor != null && items.length == kFoodPageSize;
}

/// Access to the shared food catalog, plus the user's own components.
///
/// The shared `foods` collection is read-only to clients: it is written only
/// by the migration/admin path, and client writes are rejected by Firestore
/// rules. Components the user creates for themselves go to
/// `users/{uid}/foods` instead -- see [FirestoreRefs.userFoods]. Pass [uid] to
/// enable that half; without it this behaves exactly as it always did.
class FoodRepository {
  final FirestoreRefs _refs;
  final String? uid;

  FoodRepository({FirestoreRefs? refs, this.uid})
      : _refs = refs ?? FirestoreRefs();

  Future<FoodItem?> getById(String id) async =>
      (await _refs.foods.doc(id).get()).data();

  /// Every component this user has created.
  ///
  /// Deliberately an unfiltered, unordered, unpaginated read, unlike [list]:
  /// these are hand-typed by one person, so the collection is inherently
  /// small. Filtering and sorting server-side would buy nothing at this size
  /// and would cost a composite index for the privilege, so both happen in
  /// memory -- which is also what lets the catalog re-filter them per
  /// keystroke without another read.
  Future<List<FoodItem>> listPersonal() async {
    final id = uid;
    if (id == null) return const [];
    final snapshot = await _refs.userFoods(id).get();
    final foods = snapshot.docs
        .map((document) => document.data())
        .where((food) => food.active)
        .toList();
    foods.sort((a, b) => a.name.compareTo(b.name));
    return foods;
  }

  /// Writes a new personal component and returns it with its assigned id.
  Future<FoodItem> createPersonal(FoodItem food) async {
    final id = uid;
    if (id == null) {
      throw StateError('FoodRepository needs a uid to create a component');
    }
    // The untyped reference, so `createdAt` lands in the same single write as
    // the rest of the document. Going through the converter would mean a
    // `set` followed by an `update`, i.e. two round trips and a window where
    // the document exists without it. The body still comes from the mapper,
    // so no hand-built food map escapes that boundary.
    final document =
        _refs.firestore.collection('users').doc(id).collection('foods').doc();
    await document.set({
      ...FoodMapper.toJson(food),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return food.withId(document.id);
  }

  Future<void> deletePersonal(String foodId) async {
    final id = uid;
    if (id == null) return;
    await _refs.userFoods(id).doc(foodId).delete();
  }

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

/// The Arabic fold the migration script writes `nameNormalized` with:
/// diacritics and tatweel stripped, \u0623/\u0625/\u0622 unified to \u0627, \u0629 to \u0647, \u0649 to \u064A.
///
/// Search has to fold the query the same way the stored field was folded, and
/// creating a component has to fold its name the same way the script did, or
/// a hand-created component would be unfindable by a query that matches every
/// migrated one. Both callers share this so they cannot drift apart.
String foldArabic(String input) => input
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '')
    .replaceAll(RegExp(r'[\u0623\u0625\u0622]'), '\u0627')
    .replaceAll('\u0629', '\u0647')
    .replaceAll('\u0649', '\u064A');

/// Matches the migration script's two-character minimum and Arabic fold.
String? normalizeFoodSearchToken(String? input) {
  if (input == null || input.trim().runes.length < 2) return null;
  return foldArabic(input);
}
