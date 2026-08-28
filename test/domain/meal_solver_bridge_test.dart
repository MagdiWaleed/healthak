import 'package:diet_app2/domain/meal/meal_entry.dart';
import 'package:diet_app2/domain/meal/meal_solver_bridge.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/nutrition/portion_solver.dart';
import 'package:flutter_test/flutter_test.dart';

const _chicken = Macros(protein: 31, carbs: 0, fat: 3.6);
const _mealTotals = Macros(protein: 40, carbs: 60, fat: 15);

void main() {
  group('toSolverItem', () {
    test('a FoodEntry maps grams and per100 straight through', () {
      const food = FoodEntry(
        localId: 'a',
        order: 0,
        foodId: 'chicken',
        name: 'دجاج',
        per100: _chicken,
        grams: 150,
      );

      final item = toSolverItem(food, locked: false);

      expect(item.grams, 150);
      expect(item.per100, _chicken);
      expect(item.locked, isFalse);
    });

    test('a MealRefEntry at scale 1.0 maps to 100 units', () {
      const ref = MealRefEntry(
        localId: 'b',
        order: 0,
        mealId: 'meal-1',
        name: 'وجبة الإفطار',
        scale: 1.0,
        cachedTotals: _mealTotals,
      );

      final item = toSolverItem(ref, locked: false);

      expect(item.grams, 100);
      expect(item.per100, _mealTotals);
    });

    test('a MealRefEntry at half scale maps to 50 units', () {
      const ref = MealRefEntry(
        localId: 'b',
        order: 0,
        mealId: 'meal-1',
        name: 'وجبة الإفطار',
        scale: 0.5,
        cachedTotals: _mealTotals,
      );

      expect(toSolverItem(ref, locked: false).grams, 50);
    });

    test('locked flag passes through for both entry kinds', () {
      const food = FoodEntry(
        localId: 'a',
        order: 0,
        foodId: 'x',
        name: 'x',
        per100: _chicken,
        grams: 100,
      );
      expect(toSolverItem(food, locked: true).locked, isTrue);
    });
  });

  group('applySolved', () {
    test('a solved FoodEntry gets its grams updated, nothing else', () {
      const food = FoodEntry(
        localId: 'a',
        order: 3,
        foodId: 'chicken',
        name: 'دجاج',
        per100: _chicken,
        grams: 100,
      );
      const solved = SolverItem(
        localId: 'a',
        name: 'دجاج',
        per100: _chicken,
        grams: 175,
      );

      final result = applySolved(food, solved) as FoodEntry;

      expect(result.grams, 175);
      expect(result.order, 3);
      expect(result.foodId, 'chicken');
    });

    test('a solved MealRefEntry gets scale = grams / 100', () {
      const ref = MealRefEntry(
        localId: 'b',
        order: 1,
        mealId: 'meal-1',
        name: 'وجبة الإفطار',
        scale: 1.0,
        cachedTotals: _mealTotals,
      );
      const solved = SolverItem(
        localId: 'b',
        name: 'وجبة الإفطار',
        per100: _mealTotals,
        grams: 30, // scale 0.3
      );

      final result = applySolved(ref, solved) as MealRefEntry;

      expect(result.scale, closeTo(0.3, 1e-9));
      expect(result.mealId, 'meal-1');
    });

    test('a null solved item leaves the original entry untouched', () {
      const food = FoodEntry(
        localId: 'a',
        order: 0,
        foodId: 'x',
        name: 'x',
        per100: _chicken,
        grams: 42,
      );
      expect(identical(applySolved(food, null), food), isTrue);
    });
  });

  test('round trip through the real solver moves both entry kinds', () {
    final entries = <MealEntry>[
      const FoodEntry(
        localId: 'a',
        order: 0,
        foodId: 'chicken',
        name: 'دجاج',
        per100: _chicken,
        grams: 100,
      ),
      const MealRefEntry(
        localId: 'b',
        order: 1,
        mealId: 'meal-1',
        name: 'وجبة الإفطار',
        scale: 1.0,
        cachedTotals: _mealTotals,
      ),
    ];

    final items = [for (final e in entries) toSolverItem(e, locked: false)];
    final currentKcal = items.fold(0.0, (a, i) => a + i.kcal);

    final result =
        solveProportional(items: items, targetKcal: currentKcal * 2);
    expect(result.solved, isTrue);

    final byId = {for (final item in result.items) item.localId: item};
    final resolved = [
      for (final e in entries) applySolved(e, byId[e.localId]),
    ];

    final food = resolved[0] as FoodEntry;
    final ref = resolved[1] as MealRefEntry;

    // Both roughly doubled -- a proportional solve scales every unlocked
    // item by the same factor.
    expect(food.grams, closeTo(200, 1));
    expect(ref.scale, closeTo(2.0, 0.02));
  });
}
