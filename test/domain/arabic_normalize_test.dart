import 'package:flutter_test/flutter_test.dart';
import 'package:diet_app2/domain/training/arabic_normalize.dart';

void main() {
  test('folds alef forms, ta marbuta, alif maqsura and tashkeel', () {
    expect(normalizeArabic('أإآٱ ة ى بَارِ'), 'اااا ه ي بار');
    expect(normalizeArabic('  قُوَّة  '), 'قوه');
  });
}
