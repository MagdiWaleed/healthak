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

  // Firestore needs a composite index for `orderBy(documentId, descending)`,
  // and none is deployed (it failed on device with failed-precondition). The
  // collection is one small doc per weigh-in day, so read it in the default
  // ascending order -- no index -- and pick the newest entries in memory.

  Stream<List<BodyWeightEntry>> watchLatest(int limit) => _refs
      .bodyWeights(uid)
      .snapshots()
      .map((s) => newestFirst(s.docs.map((d) => d.data()), limit));

  Future<BodyWeightEntry?> getLatest() async {
    final snapshot = await _refs.bodyWeights(uid).get();
    return newestFirst(snapshot.docs.map((d) => d.data()), 1).firstOrNull;
  }

  Future<BodyWeightEntry?> get(DateTime date) async =>
      (await _refs.bodyWeights(uid).doc(DayLog.keyFor(date)).get()).data();
  Future<void> save(BodyWeightEntry entry) =>
      _refs.bodyWeights(uid).doc(entry.dateKey).set(entry);
  Future<void> delete(String dateKey) =>
      _refs.bodyWeights(uid).doc(dateKey).delete();
}

/// The [limit] newest entries, newest first (dateKey sorts chronologically).
List<BodyWeightEntry> newestFirst(
        Iterable<BodyWeightEntry> entries, int limit) =>
    (entries.toList()..sort((a, b) => b.dateKey.compareTo(a.dateKey)))
        .take(limit)
        .toList(growable: false);
