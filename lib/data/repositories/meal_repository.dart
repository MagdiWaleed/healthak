import '../../domain/meal/meal_definition.dart';
import '../../domain/meal/meal_math.dart';
import '../firestore_refs.dart';

class MealRepository {
  final String uid;
  final FirestoreRefs _refs;

  MealRepository({required this.uid, FirestoreRefs? refs})
      : _refs = refs ?? FirestoreRefs();

  Future<List<MealDefinition>> getAll() async {
    final snapshot =
        await _refs.meals(uid).orderBy('updatedAt', descending: true).get();
    return snapshot.docs
        .map((document) => document.data())
        .toList(growable: false);
  }

  Stream<List<MealDefinition>> watchAll() => _refs
      .meals(uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((document) => document.data())
          .toList(growable: false));

  Future<MealDefinition?> get(String id) async =>
      (await _refs.meals(uid).doc(id).get()).data();

  Future<MealDefinition> save(MealDefinition draft) async {
    if (draft.ownerUid != uid) {
      throw ArgumentError.value(draft.ownerUid, 'ownerUid');
    }

    final existing = await getAll();
    final candidates = existing.where((meal) => meal.id != draft.id).toList()
      ..add(draft);
    final resolver = MealResolver(candidates);
    final computed = withRecomputedCaches(draft, resolver);
    await _refs.meals(uid).doc(computed.id).set(computed);
    return computed;
  }

  Future<void> delete(String id) => _refs.meals(uid).doc(id).delete();
}
