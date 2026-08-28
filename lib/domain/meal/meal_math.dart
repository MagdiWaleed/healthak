import '../nutrition/macros.dart';
import 'meal_definition.dart';
import 'meal_entry.dart';

/// Thrown when nesting goes deeper than [kMaxNestDepth].
class MealDepthExceeded implements Exception {
  final String mealId;
  final int depth;

  const MealDepthExceeded(this.mealId, this.depth);

  @override
  String toString() => 'MealDepthExceeded($mealId at depth $depth)';
}

/// Thrown when a meal transitively contains itself.
///
/// The `descendantMealIds` closure is supposed to make this unreachable. If it
/// fires, data was corrupted out of band -- so throw rather than recurse until
/// the stack blows.
class MealCycleException implements Exception {
  final String mealId;
  final List<String> path;

  const MealCycleException(this.mealId, this.path);

  @override
  String toString() => 'MealCycleException($mealId via ${path.join(" -> ")})';
}

/// Thrown when a referenced meal is not available to the resolver.
class MealNotFound implements Exception {
  final String mealId;

  const MealNotFound(this.mealId);

  @override
  String toString() => 'MealNotFound($mealId)';
}

/// Supplies meals to the recursive walkers, memoizing within one traversal.
///
/// A diamond -- meal C referenced from two places in the same tree -- costs one
/// resolution, not two.
class MealResolver {
  final Map<String, MealDefinition> _byId;

  MealResolver(Iterable<MealDefinition> meals)
      : _byId = {for (final m in meals) m.id: m};

  MealResolver.fromMap(Map<String, MealDefinition> byId) : _byId = byId;

  MealDefinition? lookup(String id) => _byId[id];

  MealDefinition require(String id) {
    final meal = _byId[id];
    if (meal == null) throw MealNotFound(id);
    return meal;
  }

  bool has(String id) => _byId.containsKey(id);
}

/// Total macros for a meal, recursing through nested meal references.
///
/// [visiting] carries the current path so a corrupted cycle throws instead of
/// recursing forever.
Macros macrosOfMeal(
  MealDefinition meal,
  MealResolver resolver, {
  int depth = 0,
  List<String>? visiting,
}) {
  if (depth > kMaxNestDepth) throw MealDepthExceeded(meal.id, depth);

  final path = visiting ?? <String>[];
  if (path.contains(meal.id)) {
    throw MealCycleException(meal.id, [...path, meal.id]);
  }
  path.add(meal.id);

  var total = Macros.zero;
  for (final entry in meal.entries) {
    total += switch (entry) {
      FoodEntry f => f.macros,
      MealRefEntry ref => macrosOfMeal(
            resolver.require(ref.mealId),
            resolver,
            depth: depth + 1,
            visiting: path,
          ) *
          ref.scale,
    };
  }

  path.removeLast();
  return total;
}

/// Nesting depth of the deepest branch. 0 for a meal containing only foods.
int depthOfMeal(
  MealDefinition meal,
  MealResolver resolver, {
  int depth = 0,
  List<String>? visiting,
}) {
  if (depth > kMaxNestDepth) throw MealDepthExceeded(meal.id, depth);

  final path = visiting ?? <String>[];
  if (path.contains(meal.id)) {
    throw MealCycleException(meal.id, [...path, meal.id]);
  }
  path.add(meal.id);

  var deepest = 0;
  for (final entry in meal.entries) {
    if (entry is MealRefEntry) {
      final child = resolver.lookup(entry.mealId);
      if (child == null) continue;
      final childDepth =
          1 + depthOfMeal(child, resolver, depth: depth + 1, visiting: path);
      if (childDepth > deepest) deepest = childDepth;
    }
  }

  path.removeLast();
  return deepest;
}

/// Every meal id reachable from [meal], transitively.
///
/// Stored on the meal so [canNest] is an O(1) set lookup with no extra reads.
Set<String> descendantMealIdsOf(MealDefinition meal, MealResolver resolver) {
  final found = <String>{};

  void walk(MealDefinition current, List<String> path) {
    if (path.contains(current.id)) {
      throw MealCycleException(current.id, [...path, current.id]);
    }
    path.add(current.id);

    for (final entry in current.entries) {
      if (entry is MealRefEntry) {
        found.add(entry.mealId);
        final child = resolver.lookup(entry.mealId);
        if (child != null) walk(child, path);
      }
    }

    path.removeLast();
  }

  walk(meal, <String>[]);
  return found;
}

/// Why a nesting attempt was refused. Arabic, because it is shown to the user.
enum NestRefusal {
  self('لا يمكن إضافة الوجبة إلى نفسها'),
  cycle('هذه الوجبة تحتوي بالفعل على هذه الوجبة'),
  depth('تجاوزت الحد الأقصى للتداخل'),
  leafCount('عدد المكونات تجاوز الحد المسموح');

  const NestRefusal(this.messageAr);

  final String messageAr;
}

/// The result of asking whether [child] may be nested inside [parent].
class NestCheck {
  final bool allowed;
  final NestRefusal? refusal;

  const NestCheck.allow()
      : allowed = true,
        refusal = null;

  const NestCheck.refuse(this.refusal) : allowed = false;

  String? get messageAr => refusal?.messageAr;
}

/// Whether [child] may be added as a component of [parent].
///
/// Three guards, cheapest first:
///   1. self-reference
///   2. the precomputed descendant closure -- an O(1) set lookup
///   3. resulting depth and leaf count
NestCheck canNest({
  required MealDefinition parent,
  required MealDefinition child,
  required MealResolver resolver,
}) {
  if (parent.id == child.id) return const NestCheck.refuse(NestRefusal.self);

  // If the parent is already reachable from the child, adding the child to the
  // parent closes a loop.
  if (child.descendantMealIds.contains(parent.id)) {
    return const NestCheck.refuse(NestRefusal.cycle);
  }

  final childDepth = child.depth;
  if (childDepth + 1 > kMaxNestDepth) {
    return const NestCheck.refuse(NestRefusal.depth);
  }

  final parentDepth = parent.depth;
  if (parentDepth > 0 && parentDepth + childDepth + 1 > kMaxNestDepth) {
    return const NestCheck.refuse(NestRefusal.depth);
  }

  final childLeaves = child.leafCount > 0 ? child.leafCount : 1;
  if (parent.leafCount + childLeaves > kMaxLeafCount) {
    return const NestCheck.refuse(NestRefusal.leafCount);
  }

  return const NestCheck.allow();
}

/// One flattened leaf: a real food at real grams, with no references left.
///
/// This is what a day log stores. Freezing at insert time is deliberate --
/// editing a recipe today must not retroactively change what was eaten last
/// Tuesday, and the eat-toggle hot path must not have to recurse.
class FlatItem {
  final String foodId;
  final String name;

  /// Name of the nested meal this leaf came from, so the visual grouping the
  /// user built survives flattening. Null for a top-level food.
  final String? groupLabel;

  final Macros per100;
  final double grams;

  const FlatItem({
    required this.foodId,
    required this.name,
    required this.per100,
    required this.grams,
    this.groupLabel,
  });

  Macros get macros => per100.forGrams(grams);

  double get kcal => macros.kcal;

  FlatItem copyWith({double? grams, String? groupLabel}) => FlatItem(
        foodId: foodId,
        name: name,
        per100: per100,
        grams: grams ?? this.grams,
        groupLabel: groupLabel ?? this.groupLabel,
      );

  @override
  String toString() =>
      'FlatItem($name, ${grams}g${groupLabel != null ? ", from $groupLabel" : ""})';
}

/// Collapses a meal to a flat list of leaves, multiplying grams by every scale
/// factor along the path.
List<FlatItem> flattenMeal(
  MealDefinition meal,
  MealResolver resolver, {
  double scale = 1.0,
  String? groupLabel,
  int depth = 0,
  List<String>? visiting,
}) {
  if (depth > kMaxNestDepth) throw MealDepthExceeded(meal.id, depth);

  final path = visiting ?? <String>[];
  if (path.contains(meal.id)) {
    throw MealCycleException(meal.id, [...path, meal.id]);
  }
  path.add(meal.id);

  final out = <FlatItem>[];
  for (final entry in meal.orderedEntries) {
    switch (entry) {
      case FoodEntry f:
        out.add(FlatItem(
          foodId: f.foodId,
          name: f.name,
          per100: f.per100,
          grams: f.grams * scale,
          groupLabel: groupLabel,
        ));
      case MealRefEntry ref:
        final child = resolver.require(ref.mealId);
        out.addAll(flattenMeal(
          child,
          resolver,
          scale: scale * ref.scale,
          // Innermost grouping wins, so a leaf is labelled with the meal it
          // most directly belongs to.
          groupLabel: ref.name,
          depth: depth + 1,
          visiting: path,
        ));
    }
  }

  path.removeLast();
  return out;
}

/// Total leaf count, counting through nested references.
int leafCountOfMeal(MealDefinition meal, MealResolver resolver) =>
    flattenMeal(meal, resolver).length;

/// Replaces a [MealRefEntry] with the referenced meal's leaves, at scaled
/// grams, in place.
///
/// This is what stops a reference from being a trap: whatever a meal's
/// provenance, the user can always break it open and edit individual weights.
/// Total macros are conserved.
List<MealEntry> ungroupEntry({
  required List<MealEntry> entries,
  required String localId,
  required MealResolver resolver,
  required String Function() newLocalId,
}) {
  final index = entries.indexWhere((e) => e.localId == localId);
  if (index == -1) return entries;

  final target = entries[index];
  if (target is! MealRefEntry) return entries;

  final leaves = flattenMeal(resolver.require(target.mealId), resolver,
      scale: target.scale);

  final expanded = <MealEntry>[
    for (var i = 0; i < leaves.length; i++)
      FoodEntry(
        localId: newLocalId(),
        order: 0, // renumbered below
        foodId: leaves[i].foodId,
        name: leaves[i].name,
        per100: leaves[i].per100,
        grams: leaves[i].grams,
      ),
  ];

  final result = [...entries]
    ..removeAt(index)
    ..insertAll(index, expanded);

  return renumber(result);
}

/// Rewrites `order` to match list position. Call after any structural change.
List<MealEntry> renumber(List<MealEntry> entries) => [
      for (var i = 0; i < entries.length; i++) entries[i].withOrder(i),
    ];

/// Recomputes the denormalized fields a meal carries for querying.
///
/// Call on every write. Keeping these in sync is what makes [canNest] cheap.
MealDefinition withRecomputedCaches(
  MealDefinition meal,
  MealResolver resolver,
) {
  final entries = renumber(meal.orderedEntries);
  return meal.copyWith(
    entries: entries,
    totalsCache: macrosOfMeal(meal, resolver),
    depth: depthOfMeal(meal, resolver),
    leafCount: leafCountOfMeal(meal, resolver),
    descendantMealIds: descendantMealIdsOf(meal, resolver),
    updatedAt: DateTime.now(),
  );
}
