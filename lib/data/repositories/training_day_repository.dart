import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/day/day_log.dart';
import '../../domain/training/training_day.dart';
import '../../domain/training/workout_plan_item.dart';
import '../firestore_refs.dart';

class TrainingDayRepository {
  final String uid;
  final FirestoreRefs _refs;
  final Uuid _uuid;
  TrainingDayRepository({
    required this.uid,
    FirestoreRefs? refs,
    Uuid uuid = const Uuid(),
  })  : _refs = refs ?? FirestoreRefs(),
        _uuid = uuid;

  Stream<TrainingDay?> watch(DateTime date) => _refs
      .trainingDays(uid)
      .doc(DayLog.keyFor(date))
      .snapshots()
      .map((s) => s.data());
  Stream<List<TrainingDay>> watchRange(DateTime from, DateTime to) => _refs
      .trainingDays(uid)
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: DayLog.keyFor(from))
      .where(FieldPath.documentId, isLessThanOrEqualTo: DayLog.keyFor(to))
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  Future<TrainingDay> ensureTrainingDay(
    DateTime date,
    List<WorkoutPlanItem> plan,
  ) async {
    final version = workoutPlanVersionOf(plan, date.weekday);
    final ref = _refs.trainingDays(uid).doc(DayLog.keyFor(date));
    return _refs.firestore.runTransaction((tx) async {
      final existing = (await tx.get(ref)).data();
      if (existing != null && existing.materializedFromPlanVersion == version) {
        return existing;
      }
      final day = TrainingDay.materialize(
        date: date,
        plan: plan,
        existing: existing,
        newId: _uuid.v4,
      );
      tx.set(ref, day);
      return day;
    });
  }

  Future<void> toggle(DateTime date, String localId) async {
    final ref = _refs.trainingDays(uid).doc(DayLog.keyFor(date));
    await _refs.firestore.runTransaction((tx) async {
      final day = (await tx.get(ref)).data();
      if (day == null) throw StateError('Training day does not exist');
      tx.set(ref, day.withToggled(localId, DateTime.now()));
    });
  }

  Future<void> addOneOff(DateTime date, TrainingItem item) async {
    final ref = _refs.trainingDays(uid).doc(DayLog.keyFor(date));
    await _refs.firestore.runTransaction((tx) async {
      final existing = (await tx.get(ref)).data();
      final day = existing ??
          TrainingDay(
            dateKey: DayLog.keyFor(date),
            date: DateTime(date.year, date.month, date.day),
            items: const [],
            materializedFromPlanVersion: workoutPlanVersionOf(
              const [],
              date.weekday,
            ),
          );
      tx.set(ref, day.withOneOff(item));
    });
  }
}
