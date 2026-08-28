import 'dart:math' as math;

import '../meal/meal_entry.dart';
import 'macros.dart';

/// Deterministic replacement for the bundled TFLite weight model.
///
/// The old `auto_calculate.dart` was hardcoded to exactly three components (a
/// `[6,3]` output tensor and literal `temp[0..2]` indexing), shallow-copied its
/// caller's list and then mutated the originals, and scored candidates against
/// `caloriesGoal` while having fed the model a different target. Generalizing
/// it would have meant retraining a model whose training source is not in the
/// repo.
///
/// The underlying problem -- given N components with fixed macro ratios and a
/// target, choose grams -- has a closed form. No ML required.

/// One line being solved for.
class SolverItem {
  /// Matches `MealEntry.localId`.
  final String localId;

  final String name;

  /// Macros per 100g. For a nested meal reference this is the resolved totals
  /// treated as a single composite ingredient.
  final Macros per100;

  final double grams;

  /// Locked items keep their grams. Their contribution is subtracted from the
  /// target first, and the remainder is distributed across the rest.
  ///
  /// These toggles are what make the feature feel intelligent -- far more than
  /// the model ever did.
  final bool locked;

  final double minGrams;
  final double maxGrams;

  const SolverItem({
    required this.localId,
    required this.name,
    required this.per100,
    required this.grams,
    this.locked = false,
    this.minGrams = 0,
    this.maxGrams = 2000,
  });

  Macros get macros => per100.forGrams(grams);

  double get kcal => macros.kcal;

  SolverItem withGrams(double g) => SolverItem(
        localId: localId,
        name: name,
        per100: per100,
        grams: g,
        locked: locked,
        minGrams: minGrams,
        maxGrams: maxGrams,
      );
}

/// What the solver produced, alongside enough context to show a preview diff.
class SolverResult {
  final List<SolverItem> items;

  /// Grams before solving, by `localId`, so the UI can render old -> new.
  final Map<String, double> previousGrams;

  final double targetKcal;
  final double achievedKcal;

  /// False when every item was locked, or nothing had any energy to scale.
  final bool solved;

  final String? messageAr;

  const SolverResult({
    required this.items,
    required this.previousGrams,
    required this.targetKcal,
    required this.achievedKcal,
    required this.solved,
    this.messageAr,
  });

  double get errorKcal => (achievedKcal - targetKcal).abs();

  /// Per-item change, for the preview.
  List<({String localId, String name, double from, double to})> get diff => [
        for (final item in items)
          (
            localId: item.localId,
            name: item.name,
            from: previousGrams[item.localId] ?? 0,
            to: item.grams,
          ),
      ];
}

double _roundGrams(double g) => (g / kGramRounding).round() * kGramRounding;

/// Scales every unlocked item by a single factor to hit [targetKcal].
///
/// The default mode. Always solvable, instant, and trivially explainable --
/// "everything got 15% bigger" is something a user can predict and trust.
///
/// Locked items are subtracted from the target first. Rounding residual goes to
/// the largest unlocked item, so the total lands on target rather than drifting
/// by the sum of the rounding errors.
SolverResult solveProportional({
  required List<SolverItem> items,
  required double targetKcal,
}) {
  final previous = {for (final i in items) i.localId: i.grams};

  if (items.isEmpty || targetKcal <= 0) {
    return SolverResult(
      items: items,
      previousGrams: previous,
      targetKcal: targetKcal,
      achievedKcal: items.fold(0.0, (a, i) => a + i.kcal),
      solved: false,
      messageAr: 'لا توجد مكونات لحسابها',
    );
  }

  final locked = items.where((i) => i.locked).toList();
  final unlocked = items.where((i) => !i.locked).toList();

  if (unlocked.isEmpty) {
    return SolverResult(
      items: items,
      previousGrams: previous,
      targetKcal: targetKcal,
      achievedKcal: items.fold(0.0, (a, i) => a + i.kcal),
      solved: false,
      messageAr: 'كل المكونات مثبتة',
    );
  }

  final lockedKcal = locked.fold(0.0, (a, i) => a + i.kcal);
  final remaining = targetKcal - lockedKcal;

  if (remaining <= 0) {
    return SolverResult(
      items: items,
      previousGrams: previous,
      targetKcal: targetKcal,
      achievedKcal: lockedKcal,
      solved: false,
      messageAr: 'المكونات المثبتة تتجاوز الهدف',
    );
  }

  final unlockedKcal = unlocked.fold(0.0, (a, i) => a + i.kcal);
  if (unlockedKcal <= 0) {
    return SolverResult(
      items: items,
      previousGrams: previous,
      targetKcal: targetKcal,
      achievedKcal: lockedKcal,
      solved: false,
      messageAr: 'المكونات غير المثبتة لا تحتوي على سعرات',
    );
  }

  final factor = remaining / unlockedKcal;

  final scaled = <String, SolverItem>{
    for (final i in locked) i.localId: i,
    for (final i in unlocked)
      i.localId: i.withGrams(
        _roundGrams((i.grams * factor).clamp(i.minGrams, i.maxGrams)),
      ),
  };

  // Push the rounding residual into the largest unlocked item, where it is
  // proportionally least visible.
  final achieved = scaled.values.fold(0.0, (a, i) => a + i.kcal);
  final residual = targetKcal - achieved;

  if (residual.abs() > 1) {
    final biggest = unlocked
        .map((i) => scaled[i.localId]!)
        .reduce((a, b) => a.grams >= b.grams ? a : b);

    final per100Kcal = biggest.per100.kcal;
    if (per100Kcal > 0) {
      final deltaGrams = residual / per100Kcal * 100;
      final adjusted = _roundGrams(
        (biggest.grams + deltaGrams).clamp(biggest.minGrams, biggest.maxGrams),
      );
      scaled[biggest.localId] = biggest.withGrams(adjusted);
    }
  }

  final result = [for (final i in items) scaled[i.localId]!];

  return SolverResult(
    items: result,
    previousGrams: previous,
    targetKcal: targetKcal,
    achievedKcal: result.fold(0.0, (a, i) => a + i.kcal),
    solved: true,
  );
}

/// Fits grams to a full macro target, not just an energy target.
///
/// Minimizes weighted squared error against (kcal, protein, carbs, fat) by
/// projected gradient descent, clamping to each item's bounds after every step.
/// Each step is normalized by the item's local curvature, so protein-only and
/// fat-heavy items both converge without one fixed gram learning rate making
/// one of them crawl or overshoot.
SolverResult solveForMacros({
  required List<SolverItem> items,
  required double targetKcal,
  required Macros targetMacros,
  int maxIterations = 200,
  double learningRate = 0.2,
}) {
  final previous = {for (final i in items) i.localId: i.grams};
  final unlocked = items.where((i) => !i.locked).toList();

  if (unlocked.isEmpty || items.isEmpty) {
    return solveProportional(items: items, targetKcal: targetKcal);
  }

  final lockedMacros = items
      .where((i) => i.locked)
      .fold(Macros.zero, (Macros a, i) => a + i.macros);

  // Residual the unlocked items have to cover.
  final want = Macros(
    protein: math.max(0, targetMacros.protein - lockedMacros.protein),
    carbs: math.max(0, targetMacros.carbs - lockedMacros.carbs),
    fat: math.max(0, targetMacros.fat - lockedMacros.fat),
  );
  final wantKcal = math.max(0.0, targetKcal - lockedMacros.kcal);

  // Energy is weighted hardest -- it is the number the user actually set.
  const wKcal = 1.0;
  const wMacro = 4.0;

  final grams = [for (final i in unlocked) i.grams];

  for (var iter = 0; iter < maxIterations; iter++) {
    var sumP = 0.0, sumC = 0.0, sumF = 0.0, sumK = 0.0;
    for (var i = 0; i < unlocked.length; i++) {
      final m = unlocked[i].per100.forGrams(grams[i]);
      sumP += m.protein;
      sumC += m.carbs;
      sumF += m.fat;
      sumK += m.kcal;
    }

    final errP = sumP - want.protein;
    final errC = sumC - want.carbs;
    final errF = sumF - want.fat;
    final errK = sumK - wantKcal;

    var moved = false;
    for (var i = 0; i < unlocked.length; i++) {
      final p = unlocked[i].per100;

      // d(error^2)/d(grams), with per-gram contributions being per100/100.
      final grad = 2 *
          (wMacro * errP * (p.protein / 100) +
              wMacro * errC * (p.carbs / 100) +
              wMacro * errF * (p.fat / 100) +
              wKcal * errK * (p.kcal / 100));

      // A normalized projected-gradient step. The diagonal curvature is
      // always non-negative; zero-energy items have no effect on the target
      // and therefore stay at their current grams.
      final proteinPerGram = p.protein / 100;
      final carbsPerGram = p.carbs / 100;
      final fatPerGram = p.fat / 100;
      final kcalPerGram = p.kcal / 100;
      final curvature = 2 *
          (wMacro * proteinPerGram * proteinPerGram +
              wMacro * carbsPerGram * carbsPerGram +
              wMacro * fatPerGram * fatPerGram +
              wKcal * kcalPerGram * kcalPerGram);

      if (curvature == 0) continue;

      final next = (grams[i] - learningRate * grad / curvature)
          .clamp(unlocked[i].minGrams, unlocked[i].maxGrams);

      if ((next - grams[i]).abs() > 0.01) moved = true;
      grams[i] = next;
    }

    if (!moved) break;
  }

  final solvedById = <String, SolverItem>{
    for (var i = 0; i < unlocked.length; i++)
      unlocked[i].localId: unlocked[i].withGrams(_roundGrams(grams[i])),
  };

  final result = [
    for (final i in items) solvedById[i.localId] ?? i,
  ];

  return SolverResult(
    items: result,
    previousGrams: previous,
    targetKcal: targetKcal,
    achievedKcal: result.fold(0.0, (a, i) => a + i.kcal),
    solved: true,
  );
}
