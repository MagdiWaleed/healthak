import '../day/day_log.dart';

/// The unit a price is *typed and read* in.
///
/// Storage is always per 100g -- [ComponentCost.pricePer100] and the price
/// book never change shape -- because that is the unit the food catalog's
/// `pricePer100` already uses and the unit macros are expressed in. This is
/// purely how the number is presented at the field, so switching it can never
/// alter a stored price or a computed cost.
enum PriceUnit {
  per100g('١٠٠غ', 1),

  /// What a market actually quotes: "chicken is 15 a kilo".
  perKg('كجم', 10);

  const PriceUnit(this.labelAr, this.per100Multiplier);

  final String labelAr;

  /// How many 100g units this unit contains.
  final int per100Multiplier;
}

/// Converts a price the user typed in [unit] into the stored per-100g price.
double pricePer100From(double entered, PriceUnit unit) =>
    entered / unit.per100Multiplier;

/// Converts a stored per-100g price into the number to show in [unit].
double priceIn(double pricePer100, PriceUnit unit) =>
    pricePer100 * unit.per100Multiplier;

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

  ComponentCost copyWith({double? grams, double? pricePer100, bool? skipped}) =>
      ComponentCost(
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
  int get pricedCount =>
      components.where((component) => component.isPriced).length;
  int get unpricedCount =>
      components.where((component) => component.needsPrice).length;
  double get coverage =>
      pricedCount / (components.isEmpty ? 1 : components.length);
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
