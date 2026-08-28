import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/day/day_log.dart';
import '../../domain/nutrition/energy.dart';
import '../../domain/schedule/schedule_item.dart';
import '../firestore_refs.dart';
import 'schedule_repository.dart';

class DayRepository {
  final String uid;
  final FirestoreRefs _refs;
  final ScheduleRepository _schedule;
  final Uuid _uuid;

  DayRepository({
    required this.uid,
    FirestoreRefs? refs,
    ScheduleRepository? schedule,
    Uuid uuid = const Uuid(),
  })  : _refs = refs ?? FirestoreRefs(),
        _schedule = schedule ?? ScheduleRepository(uid: uid, refs: refs),
        _uuid = uuid;

  /// Every day between [start] and [end] (inclusive) that has a document.
  ///
  /// A single range query on the document id -- `dateKey` is `yyyy-MM-dd`
  /// and Firestore doc ids sort lexically, so a month is one bounded query,
  /// not 28-31 individual reads.
  Future<List<DayLog>> getRange(DateTime start, DateTime end) async {
    final snapshot = await _refs
        .days(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: DayLog.keyFor(start))
        .where(FieldPath.documentId, isLessThanOrEqualTo: DayLog.keyFor(end))
        .get();
    return snapshot.docs.map((document) => document.data()).toList();
  }

  Stream<DayLog?> watch(DateTime date) => _refs
      .days(uid)
      .doc(DayLog.keyFor(date))
      .snapshots()
      .map((snapshot) => snapshot.data());

  Future<DayLog> ensureDay({
    required DateTime date,
    required NutritionTargets targets,
  }) async {
    final scheduled = await _schedule.getActiveFor(date);
    // Fingerprinted from the same fetch, not a stored counter -- see
    // scheduleVersionOf's doc comment.
    final scheduleVersion = scheduleVersionOf(scheduled);
    final ref = _refs.days(uid).doc(DayLog.keyFor(date));
    return _refs.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = snapshot.data();
      if (current != null &&
          current.materializedFromScheduleVersion >= scheduleVersion) {
        return current;
      }

      var day = current ?? DayLog.empty(date, targets);
      final retained = day.entries
          .where((entry) => entry.origin != DayEntryOrigin.scheduled);
      day = day.copyWith(
        entries: [
          ...retained,
          for (final item in scheduled) _fromSchedule(item),
        ],
        materializedFromScheduleVersion: scheduleVersion,
      );
      transaction.set(ref, day);
      return day;
    });
  }

  Future<void> save(DayLog day) => _refs.days(uid).doc(day.dateKey).set(day);

  Future<void> upsertEntry(String dateKey, DayEntry entry) async {
    final ref = _refs.days(uid).doc(dateKey);
    await _refs.firestore.runTransaction((transaction) async {
      final day = (await transaction.get(ref)).data();
      if (day == null) throw StateError('Day $dateKey does not exist');
      transaction.set(ref, day.withEntry(entry));
    });
  }

  Future<void> removeEntry(String dateKey, String entryId) async {
    final ref = _refs.days(uid).doc(dateKey);
    await _refs.firestore.runTransaction((transaction) async {
      final day = (await transaction.get(ref)).data();
      if (day == null) return;
      transaction.set(ref, day.withoutEntry(entryId));
    });
  }

  Future<void> toggleEaten(String dateKey, String entryId) async {
    final ref = _refs.days(uid).doc(dateKey);
    await _refs.firestore.runTransaction((transaction) async {
      final day = (await transaction.get(ref)).data();
      if (day == null) throw StateError('Day $dateKey does not exist');
      final entry =
          day.entries.where((item) => item.entryId == entryId).firstOrNull;
      if (entry == null) throw StateError('Entry $entryId does not exist');
      transaction.set(ref, day.withEntry(entry.toggleEaten()));
    });
  }

  DayEntry _fromSchedule(ScheduleItem item) => DayEntry(
        entryId: _uuid.v4(),
        origin: DayEntryOrigin.scheduled,
        scheduleItemId: item.id,
        sourceMealId: item.mealId,
        name: item.name,
        slot: item.slot,
        order: item.order,
        items: item.snapshot,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
