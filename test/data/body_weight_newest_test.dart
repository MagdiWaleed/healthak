import 'package:diet_app2/data/repositories/body_weight_repository.dart';
import 'package:diet_app2/domain/body/body_weight.dart';
import 'package:flutter_test/flutter_test.dart';

BodyWeightEntry _e(String key, double kg) {
  final d = DateTime.parse(key);
  return BodyWeightEntry(
      dateKey: key, date: d, kg: kg, createdAt: d, updatedAt: d);
}

void main() {
  test('newestFirst sorts by date key descending and limits', () {
    final entries = [
      _e('2026-10-01', 80),
      _e('2026-11-07', 78),
      _e('2026-09-30', 81),
      _e('2026-11-01', 79),
    ];
    expect(newestFirst(entries, 2).map((e) => e.dateKey),
        ['2026-11-07', '2026-11-01']);
    expect(newestFirst(entries, 10).length, 4);
    expect(newestFirst(const [], 1), isEmpty);
  });
}
