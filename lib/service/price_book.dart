import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  String _currency;

  PriceBook._(this._prefs, this._prices, this._skipped, this._currency);

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
    return PriceBook._(
        prefs, prices, skipped, prefs.getString(_currencyKey) ?? 'ج.م');
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on FormatException {
      return const {};
    }
  }

  String get currency => _currency;
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

  Future<void> setCurrency(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    _currency = normalized;
    await _prefs.setString(_currencyKey, _currency);
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _pricesKey,
      jsonEncode({'prices': _prices, 'skipped': _skipped.toList()..sort()}),
    );
  }
}
