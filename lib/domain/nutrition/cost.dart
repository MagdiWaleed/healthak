import '../day/day_log.dart';

/// A frozen food component's cost contribution over one selected period.
class ComponentCost {
  final String foodId;
  final String name;
  final double grams;
  final double? pricePer100;
  final bool skipped;

  const ComponentCost({
    required this.foodId,
    required this.name,
    required this.grams,
    this.pricePer100,
    this.skipped = false,
  });

  double? get cost => pricePer100 == null ? null : grams * pricePer100! / 100;
  bool get isPriced => cost != null;
  bool get needsPrice => !isPriced && !skipped;

  ComponentCost copyWith({double? grams, double? pricePer100, bool? skipped}) => ComponentCost(
        foodId: foodId,
        name: name,
        grams: grams ?? this.grams,
        pricePer100: pricePer100 ?? this.pricePer100,
        skipped: skipped ?? this.skipped,
      );
}

/// Aggregate cost for a day, a scheduled week, or the derived month estimate.
class PeriodCost {
  final List<ComponentCost> components;

  const PeriodCost(this.components);

  double get knownTotal =>
      components.fold(0, (total, component) => total + (component.cost ?? 0));
  int get pricedCount => components.where((component) => component.isPriced).length;
  int get unpricedCount => components.where((component) => component.needsPrice).length;
  double get coverage => pricedCount / (components.isEmpty ? 1 : components.length);
}

/// Merges flattened day leaves by catalog id. Price lookup is injected because
/// catalog reads and the local price book belong above this pure domain layer.
List<ComponentCost> aggregateFrozenItems(
  Iterable<FrozenItem> items, {
  double? Function(String foodId)? priceFor,
  bool Function(String foodId)? isSkipped,
}) {
  final totals = <String, _CostSeed>{};
  for (final item in items) {
    final existing = totals[item.foodId];
    totals[item.foodId] = _CostSeed(
      name: existing?.name ?? item.name,
      grams: (existing?.grams ?? 0) + item.grams,
    );
  }
  final result = totals.entries
      .map((entry) => ComponentCost(
            foodId: entry.key,
            name: entry.value.name,
            grams: entry.value.grams,
            pricePer100: priceFor?.call(entry.key),
            skipped: isSkipped?.call(entry.key) ?? false,
          ))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return result;
}

class _CostSeed {
  final String name;
  final double grams;
  const _CostSeed({required this.name, required this.grams});
}
