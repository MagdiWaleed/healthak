import '../meal/meal_math.dart';
import '../nutrition/energy.dart';
import '../nutrition/macros.dart';

/// Time-of-day slot. Ordering follows a normal eating day.
enum MealSlot {
  breakfast('الإفطار'),
  lunch('الغداء'),
  dinner('العشاء'),
  snack('سناك');

  const MealSlot(this.labelAr);

  final String labelAr;
}

/// How an entry got into a day.
enum DayEntryOrigin {
  /// Materialized from a `ScheduleItem` when the day was first opened.
  scheduled,

  /// Added to this day only. Never touches the schedule, gone tomorrow.
  oneShot,

  /// A loose food logged directly, without a meal around it.
  quickAdd,
}

/// A frozen leaf inside a day entry.
///
/// Identical in shape to [FlatItem], but stored rather than derived: a day is
/// an immutable historical record, so it keeps its own copy of the macros as
/// they were at the moment of logging.
class FrozenItem {
  final String foodId;
  final String name;

  /// The nested meal this leaf came from, so the grouping the user built stays
  /// visible in the day view.
  final String? groupLabel;

  final Macros per100;
  final double grams;

  const FrozenItem({
    required this.foodId,
    required this.name,
    required this.per100,
    required this.grams,
    this.groupLabel,
  });

  factory FrozenItem.fromFlat(FlatItem flat) => FrozenItem(
        foodId: flat.foodId,
        name: flat.name,
        per100: flat.per100,
        grams: flat.grams,
        groupLabel: flat.groupLabel,
      );

  Macros get macros => per100.forGrams(grams);

  double get kcal => macros.kcal;

  FrozenItem withGrams(double g) => FrozenItem(
        foodId: foodId,
        name: name,
        per100: per100,
        grams: g,
        groupLabel: groupLabel,
      );

  Map<String, dynamic> toJson() => {
        'foodId': foodId,
        'name': name,
        'groupLabel': groupLabel,
        'per100': per100.toJson(),
        'grams': grams,
      };

  factory FrozenItem.fromJson(Map<String, dynamic> json) => FrozenItem(
        foodId: json['foodId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        groupLabel: json['groupLabel'] as String?,
        per100: Macros.fromJson(
            (json['per100'] as Map?)?.cast<String, dynamic>() ?? const {}),
        grams: (json['grams'] as num?)?.toDouble() ?? 0,
      );
}

/// One meal on one day.
///
/// Fully flattened -- no references to meals, no recursion. The eat-toggle is
/// the hottest path in the app and must stay flat, and history must not change
/// when a recipe is later edited.
class DayEntry {
  final String entryId;
  final DayEntryOrigin origin;

  /// Set when [origin] is `scheduled`, so unscheduling can find its instances.
  final String? scheduleItemId;

  /// The meal this was built from, for provenance. Following it is optional --
  /// nothing about rendering a day depends on it still existing.
  final String? sourceMealId;

  final String name;
  final MealSlot slot;
  final int order;

  final bool eaten;
  final DateTime? eatenAt;

  final List<FrozenItem> items;

  const DayEntry({
    required this.entryId,
    required this.origin,
    required this.name,
    required this.slot,
    required this.order,
    required this.items,
    this.scheduleItemId,
    this.sourceMealId,
    this.eaten = false,
    this.eatenAt,
  });

  /// Always computed from [items]. There is no stored total to drift.
  Macros get totals => items.fold(Macros.zero, (Macros a, i) => a + i.macros);

  double get kcal => totals.kcal;

  /// Leaves grouped by the nested meal they came from, preserving order.
  /// Null key means a top-level food.
  Map<String?, List<FrozenItem>> get grouped {
    final out = <String?, List<FrozenItem>>{};
    for (final item in items) {
      out.putIfAbsent(item.groupLabel, () => []).add(item);
    }
    return out;
  }

  DayEntry copyWith({
    String? name,
    MealSlot? slot,
    int? order,
    bool? eaten,
    DateTime? eatenAt,
    List<FrozenItem>? items,
  }) =>
      DayEntry(
        entryId: entryId,
        origin: origin,
        scheduleItemId: scheduleItemId,
        sourceMealId: sourceMealId,
        name: name ?? this.name,
        slot: slot ?? this.slot,
        order: order ?? this.order,
        eaten: eaten ?? this.eaten,
        // Explicitly clearable: un-eating must drop the timestamp.
        eatenAt: (eaten ?? this.eaten) ? (eatenAt ?? this.eatenAt) : null,
        items: items ?? this.items,
      );

  DayEntry toggleEaten({DateTime? now}) => copyWith(
        eaten: !eaten,
        eatenAt: !eaten ? (now ?? DateTime.now()) : null,
      );
}

/// A single day. Lives at `users/{uid}/days/{yyyy-MM-dd}`.
///
/// One document, so opening the app costs one read and works offline. Eaten
/// state resets daily for free -- a new day is a new document, so `eaten` is
/// false by construction. There is no reset code, and therefore nothing to get
/// wrong. The old app persisted eaten flags forever with nothing to clear them.
class DayLog {
  /// Local-time `yyyy-MM-dd`. Also the document id, so days sort lexically.
  final String dateKey;

  final DateTime date;

  /// Offset at the time of writing. Recorded rather than corrected for -- if
  /// the user crosses a timezone, this at least says what "day" meant to them.
  final int tzOffsetMinutes;

  /// Frozen copy of the user's targets that day, so changing a goal never
  /// rewrites history.
  final NutritionTargets targets;

  final List<DayEntry> entries;

  /// Schedule version this day was materialized from, so materialization is
  /// idempotent under concurrent opens.
  final int materializedFromScheduleVersion;

  const DayLog({
    required this.dateKey,
    required this.date,
    required this.targets,
    required this.entries,
    this.tzOffsetMinutes = 0,
    this.materializedFromScheduleVersion = 0,
  });

  /// `yyyy-MM-dd` in local time. Built by hand to avoid depending on `intl`
  /// inside the domain layer, which must stay pure Dart.
  static String keyFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DayLog empty(DateTime date, NutritionTargets targets) => DayLog(
        dateKey: keyFor(date),
        date: DateTime(date.year, date.month, date.day),
        targets: targets,
        entries: const [],
        tzOffsetMinutes: date.timeZoneOffset.inMinutes,
      );

  /// Everything planned for the day, eaten or not.
  Macros get plannedTotals =>
      entries.fold(Macros.zero, (Macros a, e) => a + e.totals);

  /// Only what has actually been ticked off. This is what the ring shows.
  Macros get consumedTotals => entries
      .where((e) => e.eaten)
      .fold(Macros.zero, (Macros a, e) => a + e.totals);

  double get consumedKcal => consumedTotals.kcal;

  double get plannedKcal => plannedTotals.kcal;

  double get remainingKcal => targets.kcal - consumedKcal;

  /// Progress toward the day's energy target. Can exceed 1.
  double get progress => targets.kcal <= 0 ? 0 : consumedKcal / targets.kcal;

  bool get isOverTarget => consumedKcal > targets.kcal;

  bool get isEmpty => entries.isEmpty;

  List<DayEntry> entriesForSlot(MealSlot slot) =>
      (entries.where((e) => e.slot == slot).toList()
        ..sort((a, b) => a.order.compareTo(b.order)));

  /// Slots that actually have entries, in eating order.
  List<MealSlot> get activeSlots =>
      MealSlot.values.where((s) => entries.any((e) => e.slot == s)).toList();

  DayLog copyWith({
    NutritionTargets? targets,
    List<DayEntry>? entries,
    int? materializedFromScheduleVersion,
  }) =>
      DayLog(
        dateKey: dateKey,
        date: date,
        tzOffsetMinutes: tzOffsetMinutes,
        targets: targets ?? this.targets,
        entries: entries ?? this.entries,
        materializedFromScheduleVersion: materializedFromScheduleVersion ??
            this.materializedFromScheduleVersion,
      );

  DayLog withEntry(DayEntry entry) {
    final index = entries.indexWhere((e) => e.entryId == entry.entryId);
    if (index == -1) return copyWith(entries: [...entries, entry]);

    final next = [...entries];
    next[index] = entry;
    return copyWith(entries: next);
  }

  DayLog withoutEntry(String entryId) => copyWith(
        entries: entries.where((e) => e.entryId != entryId).toList(),
      );
}
