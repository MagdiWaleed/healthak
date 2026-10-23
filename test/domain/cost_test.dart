import 'package:diet_app2/domain/nutrition/cost.dart';
import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('component cost uses grams and price per 100g', () {
    const component = ComponentCost(
        foodId: 'rice', name: 'Rice', grams: 250, pricePer100: 12);
    expect(component.cost, 30);
  });

  test('period tracks known total, coverage, and skipped components', () {
    const priced =
        ComponentCost(foodId: 'a', name: 'A', grams: 100, pricePer100: 10);
    const missing = ComponentCost(foodId: 'b', name: 'B', grams: 100);
    const skipped =
        ComponentCost(foodId: 'c', name: 'C', grams: 100, skipped: true);
    const period = PeriodCost([priced, missing, skipped]);

    expect(period.knownTotal, 10);
    expect(period.pricedCount, 1);
    expect(period.unpricedCount, 1);
    expect(period.coverage, closeTo(1 / 3, .001));
  });

  test('frozen items merge by food id before price resolution', () {
    const per100 = Macros(protein: 1, carbs: 1, fat: 1);
    final components = aggregateFrozenItems(
      const [
        FrozenItem(foodId: 'rice', name: 'Rice', grams: 100, per100: per100),
        FrozenItem(foodId: 'rice', name: 'Rice', grams: 150, per100: per100),
        FrozenItem(foodId: 'egg', name: 'Egg', grams: 50, per100: per100),
      ],
      priceFor: (id) => id == 'rice' ? 10 : null,
    );
    final rice =
        components.singleWhere((component) => component.foodId == 'rice');
    expect(rice.grams, 250);
    expect(rice.cost, 25);
  });

  test('a skipped component is neither priced nor still missing a price', () {
    const skipped =
        ComponentCost(foodId: 'salt', name: 'Salt', grams: 20, skipped: true);
    // The point of the skip marker: it stops counting toward "بلا سعر"
    // without inventing a price of zero, which would silently understate
    // every total it appeared in.
    expect(skipped.cost, isNull);
    expect(skipped.isPriced, isFalse);
    expect(skipped.needsPrice, isFalse);
    expect(const PeriodCost([skipped]).knownTotal, 0);
  });

  test('scaling grams to another period keeps the price and rescales the cost',
      () {
    // How the month estimate is derived: one week's aggregate, x 30.4/7.
    const week = ComponentCost(
        foodId: 'rice', name: 'Rice', grams: 700, pricePer100: 10);
    final month = week.copyWith(grams: week.grams * 30.4 / 7);
    expect(month.pricePer100, 10);
    expect(month.grams, closeTo(3040, 0.001));
    expect(month.cost, closeTo(304, 0.001));
  });

  test('a per-kilo price prices a part of a kilo correctly', () {
    // The worked example: chicken is 15 a kilo, and 200g is in the plan.
    final perHundred = pricePer100From(15, PriceUnit.perKg);
    expect(perHundred, closeTo(1.5, 0.0001));

    final chicken = ComponentCost(
      foodId: 'chicken',
      name: 'صدور دجاج',
      grams: 200,
      pricePer100: perHundred,
    );
    expect(chicken.cost, closeTo(3, 0.0001));
  });

  test('unit conversion round-trips, and per-100g is the identity', () {
    expect(priceIn(1.5, PriceUnit.perKg), closeTo(15, 0.0001));
    expect(priceIn(1.5, PriceUnit.per100g), closeTo(1.5, 0.0001));
    expect(pricePer100From(1.5, PriceUnit.per100g), closeTo(1.5, 0.0001));
    for (final unit in PriceUnit.values) {
      expect(pricePer100From(priceIn(2.75, unit), unit), closeTo(2.75, 1e-9));
    }
  });

  test('switching the display unit does not move a cost', () {
    // The unit is presentation only: the same stored price, read either way,
    // has to produce the same money.
    const component = ComponentCost(
        foodId: 'rice', name: 'Rice', grams: 1000, pricePer100: 1.2);
    for (final unit in PriceUnit.values) {
      final retyped =
          pricePer100From(priceIn(component.pricePer100!, unit), unit);
      expect(component.copyWith(pricePer100: retyped).cost,
          closeTo(component.cost!, 1e-9));
    }
  });

  test('aggregation is sorted by name so rows do not reshuffle on reload', () {
    const per100 = Macros(protein: 1, carbs: 1, fat: 1);
    final components = aggregateFrozenItems(const [
      FrozenItem(foodId: 'c', name: 'Zucchini', grams: 10, per100: per100),
      FrozenItem(foodId: 'a', name: 'Apple', grams: 10, per100: per100),
      FrozenItem(foodId: 'b', name: 'Melon', grams: 10, per100: per100),
    ]);
    expect(components.map((component) => component.name),
        ['Apple', 'Melon', 'Zucchini']);
  });
}
