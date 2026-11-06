import '../body/body_weight.dart';
import '../day/day_log.dart';
import '../training/training_day.dart';

class StreakResult {
  final int current;
  final int best;
  const StreakResult({required this.current, required this.best});
}

StreakResult computeStreak(Set<String> hitDateKeys, DateTime today) {
  // Calendar days in UTC: a local Duration(days: 1) is 23 or 25 hours across a
  // DST change, which broke or skipped a streak day.
  final dates = hitDateKeys
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .map((d) => DateTime.utc(d.year, d.month, d.day))
      .toList()
    ..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final date in dates) {
    run =
        previous != null && date.difference(previous).inDays == 1 ? run + 1 : 1;
    if (run > best) best = run;
    previous = date;
  }
  var cursor = DateTime(today.year, today.month, today.day);
  if (!hitDateKeys.contains(DayLog.keyFor(cursor))) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var current = 0;
  while (hitDateKeys.contains(DayLog.keyFor(cursor))) {
    current++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return StreakResult(current: current, best: best);
}

class DailyKcal {
  final String dateKey;
  final double kcalEaten;
  const DailyKcal(this.dateKey, this.kcalEaten);
}

class WeeklyRecap {
  final double avgKcal;
  final int daysLogged;
  final int sessionsDone;
  final int sessionsPlanned;
  final double? weightDeltaKg;
  const WeeklyRecap({
    required this.avgKcal,
    required this.daysLogged,
    required this.sessionsDone,
    required this.sessionsPlanned,
    required this.weightDeltaKg,
  });

  factory WeeklyRecap.fromWindow({
    required DateTime start,
    required Iterable<DailyKcal> calories,
    required Iterable<TrainingDay> trainingDays,
    required Iterable<BodyWeightEntry> weights,
  }) {
    final end = start.add(const Duration(days: 6));
    bool inWindow(String key) =>
        key.compareTo(DayLog.keyFor(start)) >= 0 &&
        key.compareTo(DayLog.keyFor(end)) <= 0;
    final logged = calories.where((e) => inWindow(e.dateKey)).toList();
    final sessions =
        trainingDays.where((e) => inWindow(e.dateKey) && !e.isRestDay).toList();
    final sortedWeights = weights.where((e) => inWindow(e.dateKey)).toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return WeeklyRecap(
      avgKcal: logged.isEmpty
          ? 0
          : logged.fold<double>(0, (sum, e) => sum + e.kcalEaten) /
              logged.length,
      daysLogged: logged.length,
      sessionsDone: sessions.where((e) => e.isComplete).length,
      sessionsPlanned: sessions.length,
      weightDeltaKg: sortedWeights.length < 2
          ? null
          : sortedWeights.last.kg - sortedWeights.first.kg,
    );
  }
}
