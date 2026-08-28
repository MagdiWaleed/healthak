import 'package:diet_app2/data/repositories/food_repository.dart';
import 'package:diet_app2/domain/food/food_item.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
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

  group('foldArabic', () {
    test('folds the same forms as the search tokenizer', () {
      expect(foldArabic('دَجَاج'), 'دجاج');
      expect(foldArabic('إبراهيم'), 'ابراهيم');
      expect(foldArabic('أرز'), 'ارز');
      expect(foldArabic('حلاوة'), 'حلاوه');
      expect(foldArabic('مصفى'), 'مصفي');
    });

    test('has no length floor, unlike the search tokenizer', () {
      // A one-character component name still has to get a usable
      // nameNormalized written for it; only *searching* has a two-character
      // minimum.
      expect(foldArabic('أ'), 'ا');
      expect(normalizeFoodSearchToken('أ'), isNull);
    });

    test('a created component is findable by the search fold of its name', () {
      // The regression this guards: if the two folds ever diverge, a
      // hand-created component becomes unsearchable while every migrated one
      // stays findable.
      const typed = 'شَاي أخضر';
      final stored = foldArabic(typed);
      expect(stored.contains(normalizeFoodSearchToken('أخضر')!), isTrue);
      expect(stored.contains(normalizeFoodSearchToken('اخضر')!), isTrue);
    });
  });

  group('FoodItem.withId', () {
    test('rebinds identity and preserves every other field', () {
      const original = FoodItem(
        id: '',
        name: 'كبسة',
        nameNormalized: 'كبسه',
        category: 'كارب',
        per100: Macros(protein: 6, carbs: 30, fat: 4),
        kcalPer100: 180,
        note: 'بيتي',
      );

      final saved = original.withId('abc123');

      expect(saved.id, 'abc123');
      expect(saved.name, original.name);
      expect(saved.nameNormalized, original.nameNormalized);
      expect(saved.category, original.category);
      expect(saved.per100, original.per100);
      expect(saved.note, original.note);
      expect(saved.active, isTrue);
      // Identity is the equality key, so this must read as a different food.
      expect(saved == original, isFalse);
    });
  });
}
