import 'package:diet_app2/domain/profile/body_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 7);
  BodyStatsError? check(
          {int? year = 2000, double? height = 170, double? weight = 70}) =>
      validateBodyStats(
          birthYear: year, heightCm: height, weightKg: weight, now: now);

  test('height boundaries', () {
    expect(check(height: 99), BodyStatsError.height);
    expect(check(height: 100), isNull);
    expect(check(height: 250), isNull);
    expect(check(height: 251), BodyStatsError.height);
  });
  test('weight boundaries', () {
    expect(check(weight: 24.9), BodyStatsError.weight);
    expect(check(weight: 25), isNull);
    expect(check(weight: 350), isNull);
    expect(check(weight: 350.1), BodyStatsError.weight);
  });
  test('age boundaries', () {
    expect(check(year: 2014), BodyStatsError.birthYear);
    expect(check(year: 2013), isNull);
    expect(check(year: 1926), isNull);
    expect(check(year: 1925), BodyStatsError.birthYear);
  });
  test('null and nonfinite values', () {
    expect(check(year: null), BodyStatsError.birthYear);
    expect(check(height: null), BodyStatsError.height);
    expect(check(weight: null), BodyStatsError.weight);
    expect(check(height: double.nan), BodyStatsError.height);
    expect(check(height: double.infinity), BodyStatsError.height);
    expect(check(weight: double.nan), BodyStatsError.weight);
    expect(check(weight: double.negativeInfinity), BodyStatsError.weight);
  });
}
