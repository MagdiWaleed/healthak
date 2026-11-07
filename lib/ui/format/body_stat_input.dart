import 'package:flutter/widgets.dart';

import 'number_input.dart';

double? parseBodyStat(String text) =>
    text.trim().isEmpty ? null : parseNutritionAmount(text);

int? parseBirthYear(String text) => parseBodyStat(text)?.round();

void selectAllOnFocus(TextEditingController controller) {
  controller.selection =
      TextSelection(baseOffset: 0, extentOffset: controller.text.length);
}
