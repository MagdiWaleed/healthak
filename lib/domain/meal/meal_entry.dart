import '../nutrition/macros.dart';

/// Maximum nesting depth for meals-inside-meals. A meal at depth 0 may contain
/// meals at depth 1, 2, and 3. Beyond that the UI stops being comprehensible
/// long before the math does.
const int kMaxNestDepth = 3;

/// Maximum number of leaf food entries a meal may resolve to, counting through
/// every nested reference.
const int kMaxLeafCount = 60;

/// Grams are rounded to this multiple. Nobody weighs to 1g.
const double kGramRounding = 5;

/// One line in a meal.
///
/// A sealed hierarchy, so `switch` over it is exhaustive. Adding a third kind
/// later -- a barcode scan, a quick "just 200 kcal" entry -- becomes a compile
/// error at every call site instead of a silent fallthrough.
sealed class MealEntry {
  /// Stable identity that survives reordering.
  ///
  /// The old code addressed components by list index, which meant a reorder
  /// silently repointed every edit. Never use position as identity.
  final String localId;

  final int order;

  const MealEntry({required this.localId, required this.order});

  /// Display name, denormalized so a list renders offline with no lookups.
  String get name;

  MealEntry withOrder(int newOrder);
}

/// A raw food at a specific weight.
final class FoodEntry extends MealEntry {
  final String foodId;

  @override
  final String name;

  /// Snapshot of the catalog row's macros at the time it was added. Kept local
  /// so a meal renders without resolving the catalog, and so a later edit to
  /// the catalog does not silently rewrite an existing meal.
  final Macros per100;

  final double grams;

  const FoodEntry({
    required super.localId,
    required super.order,
    required this.foodId,
    required this.name,
    required this.per100,
    required this.grams,
  });

  Macros get macros => per100.forGrams(grams);

  double get kcal => macros.kcal;

  FoodEntry copyWith(
          {String? name, Macros? per100, double? grams, int? order}) =>
      FoodEntry(
        localId: localId,
        order: order ?? this.order,
        foodId: foodId,
        name: name ?? this.name,
        per100: per100 ?? this.per100,
        grams: grams ?? this.grams,
      );

  @override
  FoodEntry withOrder(int newOrder) => copyWith(order: newOrder);

  @override
  String toString() => 'FoodEntry($name, ${grams}g)';
}

/// A reference to another meal, used as a component of this one.
///
/// This is what makes "treat a composite meal as a component" work. [scale]
/// multiplies every leaf gram of the referenced meal, so a half portion is
/// `scale: 0.5`.
final class MealRefEntry extends MealEntry {
  final String mealId;

  @override
  final String name;

  final double scale;

  /// Last resolved totals for the referenced meal at scale 1.0. A render hint
  /// only -- always recompute through [MealResolver] before saving or logging.
  final Macros cachedTotals;

  final DateTime? cachedAt;

  const MealRefEntry({
    required super.localId,
    required super.order,
    required this.mealId,
    required this.name,
    required this.scale,
    this.cachedTotals = Macros.zero,
    this.cachedAt,
  });

  /// Cached totals scaled. Cheap, and stale by construction -- see [cachedTotals].
  Macros get approximateMacros => cachedTotals * scale;

  MealRefEntry copyWith({
    String? name,
    double? scale,
    Macros? cachedTotals,
    DateTime? cachedAt,
    int? order,
  }) =>
      MealRefEntry(
        localId: localId,
        order: order ?? this.order,
        mealId: mealId,
        name: name ?? this.name,
        scale: scale ?? this.scale,
        cachedTotals: cachedTotals ?? this.cachedTotals,
        cachedAt: cachedAt ?? this.cachedAt,
      );

  @override
  MealRefEntry withOrder(int newOrder) => copyWith(order: newOrder);

  @override
  String toString() => 'MealRefEntry($name, x$scale)';
}
