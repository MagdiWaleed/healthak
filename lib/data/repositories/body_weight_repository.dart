import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/body/body_weight.dart';
import '../../domain/day/day_log.dart';
import '../firestore_refs.dart';

class BodyWeightRepository {
  final String uid;
  final FirestoreRefs _refs;
  BodyWeightRepository({required this.uid, FirestoreRefs? refs})
      : _refs = refs ?? FirestoreRefs();

  Stream<List<BodyWeightEntry>> watchRange(DateTime from, DateTime to) => _refs
      .bodyWeights(uid)
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: DayLog.keyFor(from))
      .where(FieldPath.documentId, isLessThanOrEqualTo: DayLog.keyFor(to))
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  Stream<List<BodyWeightEntry>> watchLatest(int limit) => _refs
      .bodyWeights(uid)
      .orderBy(FieldPath.documentId, descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  Future<BodyWeightEntry?> getLatest() async {
    final snapshot = await _refs
        .bodyWeights(uid)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.data();
  }

  Future<BodyWeightEntry?> get(DateTime date) async =>
      (await _refs.bodyWeights(uid).doc(DayLog.keyFor(date)).get()).data();
  Future<void> save(BodyWeightEntry entry) =>
      _refs.bodyWeights(uid).doc(entry.dateKey).set(entry);
  Future<void> delete(String dateKey) =>
      _refs.bodyWeights(uid).doc(dateKey).delete();
}
