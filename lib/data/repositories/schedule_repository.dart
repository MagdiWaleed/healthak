import '../../domain/schedule/schedule_item.dart';
import '../firestore_refs.dart';

class ScheduleRepository {
  final String uid;
  final FirestoreRefs _refs;

  ScheduleRepository({required this.uid, FirestoreRefs? refs})
      : _refs = refs ?? FirestoreRefs();

  Future<List<ScheduleItem>> getAll() async {
    final snapshot = await _refs.schedule(uid).orderBy('order').get();
    return snapshot.docs.map((document) => document.data()).toList();
  }

  Stream<List<ScheduleItem>> watchAll() => _refs
      .schedule(uid)
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((document) => document.data())
          .toList(growable: false));

  Future<List<ScheduleItem>> getActiveFor(DateTime date) async {
    final snapshot = await _refs
        .schedule(uid)
        .where('active', isEqualTo: true)
        .where('daysOfWeek', arrayContains: date.weekday)
        .get();
    final items = snapshot.docs.map((document) => document.data()).toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  }

  Future<void> save(ScheduleItem item) =>
      _refs.schedule(uid).doc(item.id).set(item);
  Future<void> delete(String id) => _refs.schedule(uid).doc(id).delete();
}
