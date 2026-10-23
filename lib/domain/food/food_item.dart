import '../nutrition/macros.dart';

/// A row in the shared food catalog. Immutable.
///
/// Deliberately carries no `grams` and no `eaten` flag. The old
/// `SingleMaleModel` was a catalog row, a portion, *and* a checklist item all
/// at once, and that single conflation caused three separate bugs: a cached
/// `calories` field that was only correct at 100g, a controller that read that
/// field as if it were per-100g, and a tracker that held two parallel object
/// graphs and indexed between them positionally.
///
/// A portion is a `FoodEntry`. A checklist item is a `DayEntry`.
class FoodItem {
  final String id;
  final String name;

  /// Arabic-normalized name: diacritics stripped, أ/إ/آ unified to ا, ة to ه,
  /// ى to ي. Generated on write so search matches how people actually type.
  final String nameNormalized;

  final String? category;

  /// Macros per 100 grams. The only place macros are stored.
  final Macros per100;

  /// Denormalized `per100.kcal`, written so Firestore can sort on it.
  /// Never read as truth -- derive from [per100] instead.
  final double kcalPer100;

  final Map<String, num>? micros;
  final String? imageUrl;
  final double? pricePer100;
  final String? note;

  /// Soft delete. A retired food stays in the catalog so meals that reference
  /// it keep rendering.
  final bool active;

  const FoodItem({
    required this.id,
    required this.name,
    required this.per100,
    this.nameNormalized = '',
    this.category,
    this.kcalPer100 = 0,
    this.micros,
    this.imageUrl,
    this.pricePer100,
    this.note,
    this.active = true,
  });

  /// Rebinds the identity, for when Firestore assigns the id on write.
  /// Separate from [copyWith] because [id] is the equality key -- changing it
  /// makes a *different* food, and that should read as deliberate at the call
  /// site rather than hide among optional named arguments.
  FoodItem withId(String newId) => FoodItem(
        id: newId,
        name: name,
        nameNormalized: nameNormalized,
        category: category,
        per100: per100,
        kcalPer100: kcalPer100,
        micros: micros,
        imageUrl: imageUrl,
        pricePer100: pricePer100,
        note: note,
        active: active,
      );

  /// Macros for an actual portion.
  Macros macrosForGrams(double grams) => per100.forGrams(grams);

  double kcalForGrams(double grams) => macrosForGrams(grams).kcal;

  FoodItem copyWith({
    String? name,
    String? nameNormalized,
    String? category,
    Macros? per100,
    Map<String, num>? micros,
    String? imageUrl,
    double? pricePer100,
    String? note,
    bool? active,
  }) {
    final macros = per100 ?? this.per100;
    return FoodItem(
      id: id,
      name: name ?? this.name,
      nameNormalized: nameNormalized ?? this.nameNormalized,
      category: category ?? this.category,
      per100: macros,
      kcalPer100: macros.kcal,
      micros: micros ?? this.micros,
      imageUrl: imageUrl ?? this.imageUrl,
      pricePer100: pricePer100 ?? this.pricePer100,
      note: note ?? this.note,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) => other is FoodItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FoodItem($id, $name, $per100)';
}
