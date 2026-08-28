/// Macronutrients in grams.
///
/// The single macro vocabulary for the whole app: `protein`, `carbs`, `fat`.
/// The old code carried three mutually incompatible key sets for the same data
/// (`fat`/`carp` in Firestore, `fats`/`carps` in local JSON), which is how
/// values drifted between layers. There is now exactly one.
///
/// Energy is always *derived*, never stored as truth. Denormalized totals exist
/// elsewhere purely so Firestore can sort on them.
class Macros {
  final double protein;
  final double carbs;
  final double fat;

  const Macros({required this.protein, required this.carbs, required this.fat});

  static const Macros zero = Macros(protein: 0, carbs: 0, fat: 0);

  /// Atwater factors: 4 kcal/g for protein and carbs, 9 kcal/g for fat.
  double get kcal => protein * 4 + carbs * 4 + fat * 9;

  Macros operator +(Macros other) => Macros(
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
      );

  Macros operator -(Macros other) => Macros(
        protein: protein - other.protein,
        carbs: carbs - other.carbs,
        fat: fat - other.fat,
      );

  Macros operator *(double factor) => Macros(
        protein: protein * factor,
        carbs: carbs * factor,
        fat: fat * factor,
      );

  /// Scales per-100g values to an actual portion.
  Macros forGrams(double grams) => this * (grams / 100);

  Macros copyWith({double? protein, double? carbs, double? fat}) => Macros(
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
      );

  bool get isZero => protein == 0 && carbs == 0 && fat == 0;

  Map<String, dynamic> toJson() =>
      {'protein': protein, 'carbs': carbs, 'fat': fat};

  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
        protein: _toDouble(json['protein']),
        carbs: _toDouble(json['carbs']),
        fat: _toDouble(json['fat']),
      );

  /// Firestore hands back `int`, `double`, or occasionally a `String` from
  /// legacy writes. Normalize all of them rather than trusting the type.
  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is Macros &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat;

  @override
  int get hashCode => Object.hash(protein, carbs, fat);

  @override
  String toString() =>
      'Macros(P ${protein.toStringAsFixed(1)}, C ${carbs.toStringAsFixed(1)}, '
      'F ${fat.toStringAsFixed(1)} = ${kcal.toStringAsFixed(0)} kcal)';
}
