import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/nutrition/portion_solver.dart';
import 'package:flutter_test/flutter_test.dart';

SolverItem item({
  required String id,
  required Macros per100,
  double grams = 100,
  bool locked = false,
  double minGrams = 0,
  double maxGrams = 2000,
}) =>
    SolverItem(
      localId: id,
      name: id,
      per100: per100,
      grams: grams,
      locked: locked,
      minGrams: minGrams,
      maxGrams: maxGrams,
    );

void main() {
  const chicken = Macros(protein: 31, carbs: 0, fat: 3);
  const rice = Macros(protein: 2.7, carbs: 28, fat: 0.3);

  group('solveProportional', () {
    test('scales every unlocked item to the energy target', () {
      final items = [item(id: 'chicken', per100: chicken), item(id: 'rice', per100: rice)];
      final initialKcal = items.fold(0.0, (sum, current) => sum + current.kcal);

      final result = solveProportional(items: items, targetKcal: initialKcal * 2);

      expect(result.solved, isTrue);
      expect(result.errorKcal, lessThanOrEqualTo(1));
      expect(result.items.map((current) => current.grams), [200, 200]);
      expect(result.previousGrams, {'chicken': 100, 'rice': 100});
    });

    test('keeps locked entries unchanged and scales only the remainder', () {
      final locked = item(id: 'chicken', per100: chicken, locked: true);
      final adjustable = item(id: 'rice', per100: rice);
      final result = solveProportional(
        items: [locked, adjustable],
        targetKcal: locked.kcal + adjustable.kcal * 2,
      );

      expect(result.solved, isTrue);
      expect(result.items[0].grams, 100);
      expect(result.items[1].grams, 200);
      expect(result.errorKcal, lessThanOrEqualTo(1));
    });

    test('refuses all-locked input without changing it', () {
      final items = [item(id: 'chicken', per100: chicken, locked: true)];

      final result = solveProportional(items: items, targetKcal: 500);

      expect(result.solved, isFalse);
      expect(result.messageAr, isNotEmpty);
      expect(result.items.single.grams, 100);
    });

    test('refuses a target already exceeded by locked entries', () {
      final locked = item(id: 'chicken', per100: chicken, locked: true);
      final adjustable = item(id: 'rice', per100: rice);

      final result = solveProportional(
        items: [locked, adjustable],
        targetKcal: locked.kcal - 1,
      );

      expect(result.solved, isFalse);
      expect(result.messageAr, isNotEmpty);
      expect(result.items[1].grams, 100);
      expect(result.achievedKcal, locked.kcal);
    });

    test('handles zero-energy unlocked items without dividing by zero', () {
      final result = solveProportional(
        items: [item(id: 'water', per100: Macros.zero)],
        targetKcal: 500,
      );

      expect(result.solved, isFalse);
      expect(result.messageAr, isNotEmpty);
      expect(result.achievedKcal, 0);
      expect(result.items.single.grams, 100);
    });

    test('assigns a material rounding residual to the largest unlocked item', () {
      final result = solveProportional(
        items: [
          item(id: 'largest', per100: const Macros(protein: 20, carbs: 0, fat: 0)),
          item(id: 'smaller', per100: const Macros(protein: 0, carbs: 25, fat: 0), grams: 20),
        ],
        targetKcal: 143,
      );

      expect(result.solved, isTrue);
      expect(result.items[0].grams, 140);
      expect(result.items[1].grams, 30);
    });
  });

  group('solveForMacros', () {
    test('converges on a reachable macro target without negative grams', () {
      final items = [
        item(id: 'protein', per100: const Macros(protein: 20, carbs: 0, fat: 0)),
        item(id: 'carbs', per100: const Macros(protein: 0, carbs: 30, fat: 0)),
        item(id: 'fat', per100: const Macros(protein: 0, carbs: 0, fat: 10)),
      ];
      const target = Macros(protein: 30, carbs: 45, fat: 15);

      final result = solveForMacros(
        items: items,
        targetKcal: target.kcal,
        targetMacros: target,
      );
      final actual = result.items.fold(Macros.zero, (sum, current) => sum + current.macros);

      expect(result.solved, isTrue);
      expect(actual.protein, closeTo(target.protein, 1));
      expect(actual.carbs, closeTo(target.carbs, 1));
      expect(actual.fat, closeTo(target.fat, 1));
      expect(result.errorKcal, lessThanOrEqualTo(5));
      expect(result.items.every((current) => current.grams >= 0), isTrue);
    });

    test('preserves locks and per-item bounds', () {
      final locked = item(
        id: 'locked',
        per100: const Macros(protein: 20, carbs: 0, fat: 0),
        locked: true,
      );
      final bounded = item(
        id: 'bounded',
        per100: const Macros(protein: 0, carbs: 30, fat: 0),
        grams: 10,
        minGrams: 10,
        maxGrams: 40,
      );

      final result = solveForMacros(
        items: [locked, bounded],
        targetKcal: 1000,
        targetMacros: const Macros(protein: 100, carbs: 100, fat: 0),
      );

      expect(result.items[0].grams, 100);
      expect(result.items[1].grams, inInclusiveRange(10, 40));
    });
  });
}
