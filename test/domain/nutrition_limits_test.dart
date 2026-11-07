import 'package:diet_app2/domain/nutrition/limits.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portion and price boundaries', () {
    expect(isPortionGrams(0.99), isFalse);
    expect(isPortionGrams(1), isTrue);
    expect(isPortionGrams(5000), isTrue);
    expect(isPortionGrams(5000.01), isFalse);
    expect(isPrice(0), isTrue);
    expect(isPrice(-0.01), isFalse);
  });

  test('manual macro and kcal boundaries', () {
    expect(isManualEntryMacros(const Macros(protein: 1000, carbs: 0, fat: 0)),
        isTrue);
    expect(
        isManualEntryMacros(const Macros(protein: 1000.01, carbs: 0, fat: 0)),
        isFalse);
    expect(isManualEntryMacros(const Macros(protein: 250, carbs: 0, fat: 1000)),
        isTrue);
    expect(
        isManualEntryMacros(const Macros(protein: 250.01, carbs: 0, fat: 1000)),
        isFalse);
  });

  test('catalog per-100 boundaries', () {
    expect(
        isCatalogMacros(const Macros(protein: 0, carbs: 0, fat: 100)), isTrue);
    expect(isCatalogMacros(const Macros(protein: 0, carbs: 0, fat: 100.01)),
        isFalse);
    expect(
        isCatalogMacros(const Macros(protein: 50, carbs: 50, fat: 0)), isTrue);
    expect(isCatalogMacros(const Macros(protein: 50, carbs: 50.01, fat: 0)),
        isFalse);
  });
}
