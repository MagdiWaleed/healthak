import '../nutrition/portion_solver.dart';
import 'meal_entry.dart';

/// Bridges [MealEntry] (grams for a food, a scale factor for a meal
/// reference) to [SolverItem] (always grams), so the portion solver can run
/// over a meal that mixes both kinds without knowing either type exists.
///
/// A [MealRefEntry] has no grams -- it has [MealRefEntry.scale]. It is
/// presented to the solver as if `scale: 1.0` were "100 units", matching
/// [SolverItem.per100]'s own doc comment: "for a nested meal reference this
/// is the resolved totals treated as a single composite ingredient."
/// [toSolverItem] and [applySolved] are exact inverses of each other on that
/// convention.
SolverItem toSolverItem(MealEntry entry, {required bool locked}) =>
    switch (entry) {
      FoodEntry f => SolverItem(
          localId: f.localId,
          name: f.name,
          per100: f.per100,
          grams: f.grams,
          locked: locked,
          minGrams: 1,
          maxGrams: 3000,
        ),
      MealRefEntry r => SolverItem(
          localId: r.localId,
          name: r.name,
          per100: r.cachedTotals,
          grams: r.scale * 100,
          locked: locked,
          minGrams: 5, // scale 0.05
          maxGrams: 1000, // scale 10.0
        ),
    };

/// Applies a solved [SolverItem] back onto the [MealEntry] it came from.
/// `null` (the item wasn't part of the solve) returns [original] unchanged.
MealEntry applySolved(MealEntry original, SolverItem? solved) {
  if (solved == null) return original;
  return switch (original) {
    FoodEntry f => f.copyWith(grams: solved.grams),
    MealRefEntry r => r.copyWith(scale: solved.grams / 100),
  };
}
