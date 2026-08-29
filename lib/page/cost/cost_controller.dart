import 'dart:async';

import 'package:get/get.dart';

import '../../data/repositories/day_repository.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/nutrition/cost.dart';
import '../../service/price_book.dart';

enum CostPeriod {
  day('يوم'),
  week('أسبوع'),
  month('شهر');

  const CostPeriod(this.labelAr);

  final String labelAr;
}

/// Backs الميزانية: what the current diet costs per day, week, and month.
///
/// Reads only. The day stream and the schedule are the same sources the Today
/// tab uses; the one thing this screen writes is the local [PriceBook], which
/// never leaves the device.
class CostController extends GetxController {
  final String uid;
  final DayRepository _days;
  final ScheduleRepository _schedule;
  final FoodRepository _foods;

  CostController({
    required this.uid,
    DayRepository? days,
    ScheduleRepository? schedule,
    FoodRepository? foods,
  })  : _days = days ?? DayRepository(uid: uid),
        _schedule = schedule ?? ScheduleRepository(uid: uid),
        _foods = foods ?? FoodRepository(uid: uid);

  final period = CostPeriod.day.obs;
  final loading = true.obs;
  final error = RxnString();
  final components = <ComponentCost>[].obs;
  final currency = 'ج.م'.obs;

  /// Which period the numbers currently in [components] were computed for.
  ///
  /// A period switch changes the heading instantly but cannot change the
  /// figures until a schedule read and a day-range read come back. Without
  /// this the screen spent that window presenting last period's totals under
  /// the new period's title -- a week's cost labelled as a month's.
  final renderedPeriod = CostPeriod.day.obs;

  /// True while the figures on screen belong to a period the user has already
  /// moved away from.
  bool get isStale => renderedPeriod.value != period.value;

  /// True when the figures come from the weekly schedule rather than a real
  /// day log -- either because a week/month period is selected, or because
  /// today has nothing in it yet. The screen says so rather than showing a
  /// confident zero.
  final fromSchedule = false.obs;

  PriceBook? _book;
  StreamSubscription<DayLog?>? _daySubscription;
  DayLog? _day;

  /// Catalog prices are a read-only fallback beneath the local overrides and
  /// do not change while this screen is open, so each id is fetched once.
  final _catalogPrices = <String, double?>{};

  /// Guards against an older in-flight reload finishing after a newer one and
  /// overwriting it. The day stream and the period chips can both fire a
  /// reload, and the catalog fetch in the middle is a network round trip.
  int _epoch = 0;

  PeriodCost get total => PeriodCost(components);
  List<ComponentCost> get priced =>
      components.where((component) => component.isPriced).toList();
  List<ComponentCost> get unpriced =>
      components.where((component) => !component.isPriced).toList();

  @override
  void onInit() {
    super.onInit();
    unawaited(_start());
  }

  @override
  void onClose() {
    _daySubscription?.cancel();
    super.onClose();
  }

  Future<void> _start() async {
    try {
      final book = await PriceBook.load();
      _book = book;
      currency.value = book.currency;
    } catch (e) {
      error.value = e.toString();
      loading.value = false;
      return;
    }
    _daySubscription = _days.watch(DateTime.now()).listen(
      (day) {
        _day = day;
        unawaited(reload());
      },
      onError: (Object e) {
        error.value = e.toString();
        loading.value = false;
      },
    );
    await reload();
  }

  void setPeriod(CostPeriod value) {
    if (period.value == value) return;
    period.value = value;
    unawaited(reload());
  }

  Future<void> setPrice(String foodId, double pricePer100) async {
    final book = _book;
    if (book == null) return;
    await book.setPrice(foodId, pricePer100);
    await reload();
  }

  Future<void> skip(String foodId) async {
    final book = _book;
    if (book == null) return;
    await book.skip(foodId);
    await reload();
  }

  Future<void> unskip(String foodId) async {
    final book = _book;
    if (book == null) return;
    await book.unskip(foodId);
    await reload();
  }

  Future<void> setCurrency(String value) async {
    final book = _book;
    if (book == null) return;
    await book.setCurrency(value);
    currency.value = book.currency;
  }

  /// Deliberately not named `refresh` -- `GetxController` already has one, and
  /// shadowing it makes every `update()` call site ambiguous to read.
  Future<void> reload() async {
    final book = _book;
    if (book == null) return;
    final epoch = ++_epoch;
    loading.value = true;
    error.value = null;

    try {
      final today = _day?.entries.expand((entry) => entry.items).toList() ??
          const <FrozenItem>[];
      // A fresh day with nothing logged yet would otherwise read as a diet
      // that costs nothing. Fall back to the planned week, scaled to one day.
      final useSchedule = period.value != CostPeriod.day || today.isEmpty;
      final items = useSchedule ? await _weekItems() : today;
      if (epoch != _epoch) return;

      await _cacheCatalogPrices(items.map((item) => item.foodId).toSet());
      if (epoch != _epoch) return;

      var next = aggregateFrozenItems(
        items,
        priceFor: (id) => book.resolve(id, _catalogPrices[id]),
        isSkipped: book.isSkipped,
      );
      // `_weekItems` returns one week's worth. Scale it to whichever period
      // is actually on screen.
      final scale = switch (period.value) {
        CostPeriod.day => useSchedule ? 1 / 7 : 1.0,
        CostPeriod.week => 1.0,
        // 30.4 days is the mean month length; the screen says the month is an
        // estimate built from this week.
        CostPeriod.month => 30.4 / 7,
      };
      if (scale != 1.0) {
        next = next
            .map((component) =>
                component.copyWith(grams: component.grams * scale))
            .toList();
      }

      components.assignAll(next);
      fromSchedule.value = useSchedule;
      renderedPeriod.value = period.value;
    } catch (e) {
      if (epoch != _epoch) return;
      error.value = e.toString();
    } finally {
      if (epoch == _epoch) loading.value = false;
    }
  }

  /// One week of planned eating: every active schedule item counted once per
  /// weekday it runs on, plus anything added to a single day of this week that
  /// the schedule does not already account for.
  Future<List<FrozenItem>> _weekItems() async {
    final schedule = await _schedule.getAll();
    final items = <FrozenItem>[
      for (final item in schedule.where((item) => item.active))
        for (final _ in item.daysOfWeek) ...item.snapshot,
    ];

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final days =
        await _days.getRange(monday, monday.add(const Duration(days: 6)));
    for (final day in days) {
      for (final entry in day.entries) {
        // Scheduled entries are already counted above, from the schedule
        // itself -- counting the materialized copy too would double every
        // permanent meal.
        if (entry.origin == DayEntryOrigin.scheduled) continue;
        items.addAll(entry.items);
      }
    }
    return items;
  }

  Future<void> _cacheCatalogPrices(Set<String> foodIds) async {
    final missing =
        foodIds.where((id) => !_catalogPrices.containsKey(id)).toList();
    if (missing.isEmpty) return;
    // In parallel: this is one round trip per component the first time the
    // screen opens, and a sequential loop made that visibly slow.
    final fetched = await Future.wait(missing.map(_foods.getById));
    for (var i = 0; i < missing.length; i++) {
      _catalogPrices[missing[i]] = fetched[i]?.pricePer100;
    }
  }
}
