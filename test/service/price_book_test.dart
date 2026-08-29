import 'package:diet_app2/domain/nutrition/cost.dart';
import 'package:diet_app2/service/price_book.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('local override wins over the catalog and survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final book = await PriceBook.load();
    await book.setPrice('rice', 13.5);

    final restored = await PriceBook.load();
    expect(restored.resolve('rice', 8), 13.5);
    expect(restored.resolve('chicken', 8), 8);
  });

  test('skip records an intentional missing price without inventing zero',
      () async {
    SharedPreferences.setMockInitialValues({});
    final book = await PriceBook.load();
    await book.skip('spice');

    final restored = await PriceBook.load();
    expect(restored.isSkipped('spice'), isTrue);
    expect(restored.resolve('spice', null), isNull);
  });

  test('a skip can be undone without having to invent a price', () async {
    SharedPreferences.setMockInitialValues({});
    final book = await PriceBook.load();
    await book.skip('spice');
    await book.unskip('spice');

    final restored = await PriceBook.load();
    expect(restored.isSkipped('spice'), isFalse);
    expect(restored.overrideFor('spice'), isNull);
  });

  test('pricing a skipped component clears the skip', () async {
    SharedPreferences.setMockInitialValues({});
    final book = await PriceBook.load();
    await book.skip('spice');
    await book.setPrice('spice', 4);

    final restored = await PriceBook.load();
    expect(restored.isSkipped('spice'), isFalse);
    expect(restored.resolve('spice', null), 4);
  });

  test('the price unit is per component, defaults to per kilo, and persists',
      () async {
    SharedPreferences.setMockInitialValues({});
    final book = await PriceBook.load();
    expect(book.unitFor('chicken'), PriceUnit.perKg);

    // Rice by the kilo, saffron not -- one component's unit must not move
    // another's.
    await book.setUnitFor('saffron', PriceUnit.per100g);
    final restored = await PriceBook.load();
    expect(restored.unitFor('saffron'), PriceUnit.per100g);
    expect(restored.unitFor('rice'), PriceUnit.perKg);
  });

  test('changing a unit leaves stored prices untouched', () async {
    SharedPreferences.setMockInitialValues({});
    final book = await PriceBook.load();
    await book.setPrice('chicken', 1.5);
    await book.setUnitFor('chicken', PriceUnit.per100g);

    // Storage is always per 100g -- the unit is only how the field reads.
    final restored = await PriceBook.load();
    expect(restored.resolve('chicken', null), 1.5);
  });

  test('unskipping something that was never skipped is a no-op', () async {
    SharedPreferences.setMockInitialValues({});
    final book = await PriceBook.load();
    await book.setPrice('rice', 9);
    await book.unskip('rice');

    final restored = await PriceBook.load();
    expect(restored.resolve('rice', null), 9);
  });
}
