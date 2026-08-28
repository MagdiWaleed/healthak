import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const macros = Macros(protein: 20, carbs: 30, fat: 10);

  group('Macros', () {
    test('derives kcal with Atwater factors', () {
      expect(macros.kcal, 290);
    });

    test('adds and subtracts component-wise', () {
      const other = Macros(protein: 5, carbs: 10, fat: 2);

      expect(macros + other, const Macros(protein: 25, carbs: 40, fat: 12));
      expect(macros - other, const Macros(protein: 15, carbs: 20, fat: 8));
    });

    test('scales and calculates a portion from per-100g values', () {
      expect(macros * 0.5, const Macros(protein: 10, carbs: 15, fat: 5));
      expect(
        macros.forGrams(250),
        const Macros(protein: 50, carbs: 75, fat: 25),
      );
    });

    test('zero is the additive identity and reports itself as zero', () {
      expect(macros + Macros.zero, macros);
      expect(Macros.zero + macros, macros);
      expect(Macros.zero.isZero, isTrue);
      expect(macros.isZero, isFalse);
    });

    test('round-trips JSON and normalizes Firestore number representations', () {
      expect(Macros.fromJson(macros.toJson()), macros);
      expect(
        Macros.fromJson({'protein': 20, 'carbs': '30.5', 'fat': 10.0}),
        const Macros(protein: 20, carbs: 30.5, fat: 10),
      );
    });

    test('treats absent or invalid persisted values as zero', () {
      expect(
        Macros.fromJson({'protein': 'not-a-number'}),
        Macros.zero,
      );
    });

    test('value equality includes each macro and supports copyWith', () {
      expect(
        macros.copyWith(carbs: 35),
        const Macros(protein: 20, carbs: 35, fat: 10),
      );
      expect(macros.hashCode, const Macros(protein: 20, carbs: 30, fat: 10).hashCode);
    });
  });
}
