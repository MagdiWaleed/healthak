import 'package:diet_app2/data/repositories/market_repository.dart';
import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/market/market_meal.dart';
import 'package:diet_app2/domain/meal/meal_definition.dart';
import 'package:diet_app2/domain/meal/meal_entry.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final publishedAt = DateTime.utc(2026, 10, 24);
  final original = MarketMeal(
    id: 'market-1',
    authorUid: 'author',
    authorName: 'الناشر',
    name: 'وجبة الدجاج',
    items: const [
      FrozenItem(
        foodId: 'chicken',
        name: 'دجاج',
        groupLabel: null,
        per100: Macros(protein: 20, carbs: 0, fat: 3),
        grams: 100,
      ),
      FrozenItem(
        foodId: 'rice',
        name: 'أرز',
        groupLabel: null,
        per100: Macros(protein: 2, carbs: 25, fat: 0),
        grams: 150,
      ),
    ],
    version: 3,
    createdAt: publishedAt,
    updatedAt: publishedAt,
  );

  test('market copy keeps provenance but has independent ids and weights', () {
    final copied = buildMarketCopy(
      original,
      'reader',
      grams: [175, 200],
      copiedAt: DateTime.utc(2026, 10, 25),
    );
    final second = buildMarketCopy(original, 'reader');

    expect(copied.id, isNot(original.id));
    expect(copied.id, isNot(second.id));
    expect(copied.origin, MealOrigin.copiedFromMarket);
    expect(copied.source!.marketMealId, original.id);
    expect(copied.source!.version, 3);
    expect(
        copied.entries.whereType<FoodEntry>().map((e) => e.grams), [175, 200]);
    expect(
        second.entries.whereType<FoodEntry>().map((e) => e.grams), [100, 150]);
    expect(copied.entries.first.localId, isNot(second.entries.first.localId));
    expect(original.items.first.grams, 100);
  });

  test('invalid market weights are rejected before any write', () {
    expect(() => buildMarketCopy(original, 'reader', grams: [200]),
        throwsFormatException);
    expect(() => buildMarketCopy(original, 'reader', grams: [0, 150]),
        throwsFormatException);
    expect(() => buildMarketCopy(original, 'reader', grams: [double.nan, 150]),
        throwsFormatException);
  });

  test('scheduled market copy freezes edited weights and chosen weekdays', () {
    final copy = buildMarketCopy(original, 'reader', grams: [175, 200]);
    final schedule = buildMarketSchedule(
      original,
      copy,
      grams: [175, 200],
      slot: MealSlot.dinner,
      daysOfWeek: {1, 3, 5},
      order: 4,
    );
    expect(schedule.mealId, copy.id);
    expect(schedule.snapshot.map((item) => item.grams), [175, 200]);
    expect(schedule.slot, MealSlot.dinner);
    expect(schedule.daysOfWeek, {1, 3, 5});
    expect(schedule.appliesTo(DateTime.utc(2026, 10, 26)), isTrue);
    expect(schedule.appliesTo(DateTime.utc(2026, 10, 27)), isFalse);
    expect(original.items.first.grams, 100);
  });

  test('schedule requires at least one weekday', () {
    final copy = buildMarketCopy(original, 'reader');
    expect(
      () => buildMarketSchedule(original, copy,
          grams: [100, 150], slot: MealSlot.lunch, daysOfWeek: {}, order: 0),
      throwsFormatException,
    );
  });
}
