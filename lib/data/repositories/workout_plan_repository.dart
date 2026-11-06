import '../../domain/training/workout_plan_item.dart';
import '../firestore_refs.dart';

class WorkoutPlanRepository {
  final String uid;
  final FirestoreRefs _refs;
  WorkoutPlanRepository({required this.uid, FirestoreRefs? refs})
      : _refs = refs ?? FirestoreRefs();

  Stream<List<WorkoutPlanItem>> watchAll() => _refs
      .workoutPlan(uid)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
  Future<List<WorkoutPlanItem>> getAll() async {
    final result = await _refs.workoutPlan(uid).get();
    return result.docs.map((d) => d.data()).toList();
  }

  Future<void> save(WorkoutPlanItem item) =>
      _refs.workoutPlan(uid).doc(item.id).set(item);
  Future<void> saveAll(Iterable<WorkoutPlanItem> items,
      {Iterable<String> deleteIds = const []}) async {
    final batch = _refs.firestore.batch();
    for (final id in deleteIds) {
      batch.delete(_refs.workoutPlan(uid).doc(id));
    }
    for (final item in items) {
      batch.set(_refs.workoutPlan(uid).doc(item.id), item);
    }
    await batch.commit();
  }

  Future<void> delete(String id) => _refs.workoutPlan(uid).doc(id).delete();
}
