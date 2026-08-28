import 'package:diet_app2/data/mappers/food_mapper.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FoodMapper', () {
    test('maps catalog JSON while preserving the document id', () {
      final food = FoodMapper.fromJson({
        'name': 'Rice',
        'nameNormalized': 'rice',
        'category': 'grains',
        'active': true,
        'per100': {'protein': 2.7, 'carbs': 28, 'fat': 0.3},
        'kcalPer100': 999,
        'micros': {'iron': 1},
        'pricePer100': '3.5',
      }, id: 'rice');

      expect(food.id, 'rice');
      expect(food.per100, const Macros(protein: 2.7, carbs: 28, fat: 0.3));
      expect(food.kcalPer100, food.per100.kcal);
      expect(food.micros, {'iron': 1});
      expect(food.pricePer100, 3.5);
    });

    test('writes derived kcal rather than a stale denormalized value', () {
      final food = FoodMapper.fromJson({
        'name': 'Rice',
        'per100': {'protein': 2.7, 'carbs': 28, 'fat': 0.3},
        'kcalPer100': 0,
      }, id: 'rice');

      expect(FoodMapper.toJson(food)['kcalPer100'], food.per100.kcal);
    });
  });
}
