import '../day/day_log.dart';

class BodyWeightEntry {
  final String dateKey;
  final DateTime date;
  final double kg;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BodyWeightEntry({
    required this.dateKey,
    required this.date,
    required this.kg,
    required this.createdAt,
    required this.updatedAt,
  });

  BodyWeightEntry copyWith({double? kg, DateTime? updatedAt}) =>
      BodyWeightEntry(
        dateKey: dateKey,
        date: date,
        kg: kg ?? this.kg,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is BodyWeightEntry &&
      dateKey == other.dateKey &&
      date == other.date &&
      kg == other.kg &&
      createdAt == other.createdAt &&
      updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(dateKey, date, kg, createdAt, updatedAt);
}

class WeightTrend {
  final List<BodyWeightEntry> entries;
  final List<double> ema;

  WeightTrend(Iterable<BodyWeightEntry> source)
      : entries = List.unmodifiable(
          [...source]..sort((a, b) => a.dateKey.compareTo(b.dateKey)),
        ),
        ema = _ema([...source]..sort((a, b) => a.dateKey.compareTo(b.dateKey)));

  static List<double> _ema(List<BodyWeightEntry> entries) {
    if (entries.isEmpty) return const [];
    final values = <double>[entries.first.kg];
    for (final entry in entries.skip(1)) {
      values.add(.1 * entry.kg + .9 * values.last);
    }
    return List.unmodifiable(values);
  }

  double? get latestKg => entries.isEmpty ? null : entries.last.kg;
  double? get trendKg => ema.isEmpty ? null : ema.last;

  double? deltaKg(int days) {
    if (entries.length < 2 || days <= 0) return null;
    final cutoff = entries.last.date.subtract(Duration(days: days));
    for (var i = entries.length - 2; i >= 0; i--) {
      if (!entries[i].date.isAfter(cutoff)) return ema.last - ema[i];
    }
    return null;
  }

  double? get weeklyRateKg {
    if (entries.length < 2) return null;
    final cutoff = entries.last.date.subtract(const Duration(days: 14));
    final first = entries.indexWhere((e) => !e.date.isBefore(cutoff));
    if (first < 0 || first >= entries.length - 1) return null;
    final span = entries.last.date.difference(entries[first].date).inDays;
    if (span < 4) return null;
    return (ema.last - ema[first]) * 7 / span;
  }

  DateTime? etaFor(double goalKg) {
    final rate = weeklyRateKg;
    final current = trendKg;
    if (rate == null || current == null || rate.abs() < .02) return null;
    final remaining = goalKg - current;
    if (remaining == 0 || remaining / rate <= 0) return null;
    final days = (remaining / rate * 7).ceil();
    return DateTime(
      entries.last.date.year,
      entries.last.date.month,
      entries.last.date.day + days,
    );
  }

  /// A first-ever entry is not a "new low": there is nothing to beat yet, so
  /// the first weigh-in does not fire a celebration.
  bool isNewLow(BodyWeightEntry entry) {
    final earlier =
        entries.where((e) => e.dateKey.compareTo(entry.dateKey) < 0);
    return earlier.isNotEmpty && earlier.every((e) => entry.kg < e.kg);
  }

  static String keyFor(DateTime date) => DayLog.keyFor(date);
}
