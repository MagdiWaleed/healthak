import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oldMeal = Macros(protein: 10, carbs: 20, fat: 5);
  const otherMeal = Macros(protein: 4, carbs: 8, fat: 2);
  const draft = Macros(protein: 12, carbs: 24, fat: 6);

  group('DayLog planned totals after a meal draft', () {
    test('adds a new draft once to all meals already planned today', () {
      final day = _day([_entry('other', otherMeal)]);

      expect(
        day.plannedTotalsAfterDraft(
          replacingMealId: null,
          draftTotals: draft,
        ),
        otherMeal + draft,
      );
    });

    test('replaces an edited meal instead of double-counting it', () {
      final day = _day([
        _entry('edited', oldMeal, sourceMealId: 'meal-1'),
        _entry('other', otherMeal, sourceMealId: 'meal-2'),
      ]);

      expect(
        day.plannedTotalsAfterDraft(
          replacingMealId: 'meal-1',
          draftTotals: draft,
        ),
        otherMeal + draft,
      );
    });

    test('replaces every occurrence of the edited meal one-for-one', () {
      final day = _day([
        _entry('edited-1', oldMeal, sourceMealId: 'meal-1'),
        _entry('edited-2', oldMeal, sourceMealId: 'meal-1'),
        _entry('other', otherMeal, sourceMealId: 'meal-2'),
      ]);

      expect(
        day.plannedTotalsAfterDraft(
          replacingMealId: 'meal-1',
          draftTotals: draft,
        ),
        otherMeal + draft * 2,
      );
    });

    test('saved meal refresh preserves occurrence identity and eaten state',
        () {
      final eatenAt = DateTime(2026, 8, 29, 12);
      final original = _entry(
        'edited',
        oldMeal,
        sourceMealId: 'meal-1',
        eaten: true,
        eatenAt: eatenAt,
      );
      final day = _day([original, _entry('other', otherMeal)]);
      final replacementItems = [
        const FrozenItem(
          foodId: 'replacement-food',
          name: 'replacement',
          per100: draft,
          grams: 100,
        ),
      ];

      final refreshed = day.refreshMealOccurrences(
        sourceMealId: 'meal-1',
        name: 'updated meal',
        items: replacementItems,
      );
      final entry = refreshed.entries.first;

      expect(entry.entryId, original.entryId);
      expect(entry.eaten, isTrue);
      expect(entry.eatenAt, eatenAt);
      expect(entry.name, 'updated meal');
      expect(entry.totals, draft);
      expect(refreshed.entries.last, same(day.entries.last));
    });
  });
}

DayLog _day(List<DayEntry> entries) => DayLog(
      dateKey: '2026-08-29',
      date: DateTime(2026, 8, 29),
      targets: NutritionTargets.empty,
      entries: entries,
    );

DayEntry _entry(
  String id,
  Macros macros, {
  String? sourceMealId,
  bool eaten = false,
  DateTime? eatenAt,
}) =>
    DayEntry(
      entryId: id,
      origin: DayEntryOrigin.oneShot,
      sourceMealId: sourceMealId,
      eaten: eaten,
      eatenAt: eatenAt,
      name: id,
      slot: MealSlot.lunch,
      order: 0,
      items: [
        FrozenItem(
          foodId: '$id-food',
          name: id,
          per100: macros,
          grams: 100,
        ),
      ],
    );
