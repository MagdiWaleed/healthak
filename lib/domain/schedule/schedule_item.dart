import '../day/day_log.dart';
import '../nutrition/macros.dart';

/// A meal that recurs. The "permanent" half of permanent-vs-one-shot.
///
/// Lives at `users/{uid}/schedule/{itemId}`. A one-shot has no schedule item at
/// all -- it is written straight into today's [DayLog] and disappears with it.
class ScheduleItem {
  final String id;

  /// The meal in the user's library this was created from.
  final String mealId;

  final String name;

  /// Frozen leaves, so materializing a day is a single query with no meal
  /// resolution and works offline.
  ///
  /// Deliberately a snapshot: editing the underlying meal does not silently
  /// rewrite the schedule. The app asks first.
  final List<FrozenItem> snapshot;

  final MealSlot slot;
  final int order;

  /// ISO weekdays, 1 = Monday through 7 = Sunday. A full set means daily.
  final Set<int> daysOfWeek;

  /// Paused rather than deleted, so history keeps its provenance.
  final bool active;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ScheduleItem({
    required this.id,
    required this.mealId,
    required this.name,
    required this.snapshot,
    required this.slot,
    required this.order,
    required this.daysOfWeek,
    required this.createdAt,
    required this.updatedAt,
    this.active = true,
  });

  static const Set<int> everyDay = {1, 2, 3, 4, 5, 6, 7};

  bool get isDaily => daysOfWeek.length == 7;

  Macros get totals =>
      snapshot.fold(Macros.zero, (Macros a, i) => a + i.macros);

  double get kcal => totals.kcal;

  /// Whether this item should appear on [date].
  bool appliesTo(DateTime date) => active && daysOfWeek.contains(date.weekday);

  ScheduleItem copyWith({
    String? name,
    List<FrozenItem>? snapshot,
    MealSlot? slot,
    int? order,
    Set<int>? daysOfWeek,
    bool? active,
    DateTime? updatedAt,
  }) =>
      ScheduleItem(
        id: id,
        mealId: mealId,
        name: name ?? this.name,
        snapshot: snapshot ?? this.snapshot,
        slot: slot ?? this.slot,
        order: order ?? this.order,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        active: active ?? this.active,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  bool operator ==(Object other) => other is ScheduleItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A content fingerprint over a day's scheduled items, used to decide whether
/// [DayLog.materializedFromScheduleVersion] is stale.
///
/// There is deliberately no persisted counter for this. A stored version would
/// need its own document (or a field on the profile) that every schedule write
/// updates transactionally, which is exactly the extra read/write the flat,
/// one-read day model exists to avoid. Since [ensureDay] already has to fetch
/// today's active items to materialize them, hashing that same list is free.
///
/// `updatedAt` is included so editing an item in place -- same id, same slot,
/// same order, different snapshot -- still produces a new version. `id` and
/// `order` alone would miss that.
int scheduleVersionOf(List<ScheduleItem> items) {
  final sorted = [...items]..sort((a, b) => a.id.compareTo(b.id));
  return Object.hashAll([
    for (final item in sorted)
      Object.hash(item.id, item.order, item.updatedAt.millisecondsSinceEpoch),
  ]);
}
