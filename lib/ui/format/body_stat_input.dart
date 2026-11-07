import 'number_input.dart';

double? parseBodyStat(String text) =>
    text.trim().isEmpty ? null : parseNutritionAmount(text);

int? parseBirthYear(String text) => parseBodyStat(text)?.round();
