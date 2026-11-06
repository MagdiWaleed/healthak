import 'package:diet_app2/domain/body/body_weight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BodyWeightEntry entry(int day, double kg) {
    final date = DateTime(2026, 1, day);
    return BodyWeightEntry(
      dateKey: '2026-01-${day.toString().padLeft(2, '0')}',
      date: date,
      kg: kg,
      createdAt: date,
      updatedAt: date,
    );
  }

  test('sorts and computes EMA, delta, rate, ETA and lows', () {
    final trend = WeightTrend([entry(15, 78), entry(1, 80), entry(8, 79)]);
    expect(trend.entries.first.kg, 80);
    expect(trend.ema[0], 80);
    expect(trend.ema[1], closeTo(79.9, .0001));
    expect(trend.ema[2], closeTo(79.71, .0001));
    expect(trend.latestKg, 78);
    expect(trend.deltaKg(7), closeTo(-.19, .0001));
    expect(trend.weeklyRateKg, closeTo(-.145, .0001));
    expect(trend.etaFor(79), isNotNull);
    expect(trend.etaFor(81), isNull);
    expect(trend.isNewLow(entry(15, 78)), isTrue);
    expect(trend.isNewLow(entry(20, 80)), isFalse);
  });
  test('sparse or flat history has no rate or ETA', () {
    expect(WeightTrend([]).latestKg, isNull);
    // The first-ever weigh-in has nothing to beat, so it is not a new low.
    expect(WeightTrend([]).isNewLow(entry(1, 80)), isFalse);
    expect(WeightTrend([entry(1, 80)]).isNewLow(entry(1, 80)), isFalse);
    expect(WeightTrend([entry(1, 80)]).deltaKg(7), isNull);
    expect(WeightTrend([entry(1, 80), entry(3, 79)]).weeklyRateKg, isNull);
    expect(WeightTrend([entry(1, 80), entry(15, 80)]).etaFor(75), isNull);
  });
}
