import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/nutrition/cost.dart';

/// Local market-price overrides for diet-cost estimates.
///
/// This deliberately stays on this device. If prices ever need to follow a
/// user across devices, promote this data to `users/{uid}/priceBook`; do not
/// add that Firestore shape until that product decision is made.
class PriceBook {
  static const _pricesKey = 'priceBook.v1';
  static const _currencyKey = 'priceBook.currency';

  final SharedPreferences _prefs;
  final Map<String, double> _prices;
  final Set<String> _skipped;

  /// Per food, the unit its price is typed and read in. Rice is bought by
  /// the kilo and saffron is not, so this is a property of the component,
  /// not a setting for the whole screen.
  final Map<String, PriceUnit> _units;
  String _currency;

  PriceBook._(
    this._prefs,
    this._prices,
    this._skipped,
    this._units,
    this._currency,
  );

  static Future<PriceBook> load({SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_pricesKey);
    final decoded = raw == null ? const <String, dynamic>{} : _decode(raw);
    final prices = <String, double>{
      for (final entry in (decoded['prices'] as Map? ?? const {}).entries)
        if (entry.value is num)
          entry.key.toString(): (entry.value as num).toDouble(),
    };
    final skipped = <String>{
      for (final id in (decoded['skipped'] as List? ?? const [])) id.toString(),
    };
    final units = <String, PriceUnit>{
      for (final entry in (decoded['units'] as Map? ?? const {}).entries)
        for (final unit in PriceUnit.values)
          if (unit.name == entry.value) entry.key.toString(): unit,
    };
    return PriceBook._(
      prefs,
      prices,
      skipped,
      units,
      prefs.getString(_currencyKey) ?? 'ج.م',
    );
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on FormatException {
      return const {};
    }
  }

  String get currency => _currency;

  /// Per kilo is how a market quotes a price, so it is what someone filling
  /// this in is reading off a receipt. Storage stays per 100g either way --
  /// see [PriceUnit].
  PriceUnit unitFor(String foodId) => _units[foodId] ?? PriceUnit.perKg;

  Map<String, PriceUnit> get units => Map.unmodifiable(_units);
  bool isSkipped(String foodId) => _skipped.contains(foodId);
  double? overrideFor(String foodId) => _prices[foodId];
  double? resolve(String foodId, double? catalogPricePer100) =>
      _prices[foodId] ?? catalogPricePer100;

  Future<void> setPrice(String foodId, double pricePer100) async {
    if (pricePer100 < 0) throw ArgumentError.value(pricePer100, 'pricePer100');
    _prices[foodId] = pricePer100;
    _skipped.remove(foodId);
    await _persist();
  }

  Future<void> skip(String foodId) async {
    _prices.remove(foodId);
    _skipped.add(foodId);
    await _persist();
  }

  /// Undoes a [skip], putting the component back among the ones still
  /// waiting for a price. A skip is a judgement call ("this one is not worth
  /// pricing"), not a deletion, so it has to be reversible without having to
  /// invent a price to get out of it.
  Future<void> unskip(String foodId) async {
    if (!_skipped.remove(foodId)) return;
    await _persist();
  }

  /// Changes only how [foodId]'s price is displayed and typed. The stored
  /// per-100g price is untouched, so the component's cost does not move.
  Future<void> setUnitFor(String foodId, PriceUnit value) async {
    if (unitFor(foodId) == value) return;
    _units[foodId] = value;
    await _persist();
  }

  Future<void> setCurrency(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    _currency = normalized;
    await _prefs.setString(_currencyKey, _currency);
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _pricesKey,
      jsonEncode({
        'prices': _prices,
        'skipped': _skipped.toList()..sort(),
        'units': {
          for (final entry in _units.entries) entry.key: entry.value.name,
        },
      }),
    );
  }
}
