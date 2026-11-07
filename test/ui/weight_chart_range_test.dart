import 'package:flutter_test/flutter_test.dart';
import 'package:diet_app2/ui/components/weight_chart.dart';

void main() {
  test('nearby goal participates in chart range', () {
    final range = chartYRange([90, 92], 86);
    expect(range.showGoalLine, isTrue);
    expect(range.minY, lessThan(86));
    expect(range.maxY, greaterThan(92));
  });

  test('distant goal stays outside chart range', () {
    final range = chartYRange([90, 92], 70);
    expect(range.showGoalLine, isFalse);
    expect(range.minY, greaterThan(70));
  });

  test('distant goal above the data also stays outside chart range', () {
    final range = chartYRange([90, 92], 120);
    expect(range.showGoalLine, isFalse);
    expect(range.maxY, lessThan(120));
  });

  test('a single weight has a nonzero visible range', () {
    final range = chartYRange([90], null);
    expect(range.maxY, greaterThan(range.minY));
  });
}
