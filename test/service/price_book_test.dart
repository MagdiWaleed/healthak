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

  test('unskipping something that was never skipped is a no-op', () async {
    SharedPreferences.setMockInitialValues({});
    final book = await PriceBook.load();
    await book.setPrice('rice', 9);
    await book.unskip('rice');

    final restored = await PriceBook.load();
    expect(restored.resolve('rice', null), 9);
  });
}
