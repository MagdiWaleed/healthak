/// Parses decimal input from Arabic and Western keyboards without accepting
/// negative, non-finite, or malformed nutrition amounts. Blank means zero.
double? parseNutritionAmount(String input) {
  var value = input.trim();
  if (value.isEmpty) return 0;
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  value = value.replaceAll('٫', '.');
  final parsed = double.tryParse(value);
  return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
}
