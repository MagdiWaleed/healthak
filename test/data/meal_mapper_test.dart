import 'package:diet_app2/data/mappers/meal_mapper.dart';
import 'package:diet_app2/domain/meal/meal_definition.dart';
import 'package:diet_app2/domain/meal/meal_entry.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meal mapper preserves sealed entry kinds and ordering', () {
    final now = DateTime(2026, 8, 28);
    final meal = MealDefinition(
      id: 'meal-1',
      ownerUid: 'u1',
      name: 'Lunch',
      entries: [
        const FoodEntry(
          localId: 'food-1',
          order: 0,
          foodId: 'rice',
          name: 'Rice',
          per100: Macros(protein: 2, carbs: 28, fat: 0),
          grams: 150,
        ),
        MealRefEntry(
          localId: 'ref-1',
          order: 1,
          mealId: 'sauce',
          name: 'Sauce',
          scale: .5,
          cachedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final restored = MealMapper.fromJson(MealMapper.toJson(meal), id: meal.id);

    expect(restored.entries, hasLength(2));
    expect(restored.entries.first, isA<FoodEntry>());
    expect(restored.entries.last, isA<MealRefEntry>());
    expect(restored.entries.map((entry) => entry.order), [0, 1]);
  });
}
