import 'package:diet_app2/data/repositories/food_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeFoodSearchToken', () {
    test('rejects empty and one-character searches', () {
      expect(normalizeFoodSearchToken(null), isNull);
      expect(normalizeFoodSearchToken(' د '), isNull);
    });

    test('normalizes Arabic forms like the catalog migration', () {
      expect(normalizeFoodSearchToken('دَجَاج'), 'دجاج');
      expect(normalizeFoodSearchToken('إبراهيم'), 'ابراهيم');
    });
  });
}
