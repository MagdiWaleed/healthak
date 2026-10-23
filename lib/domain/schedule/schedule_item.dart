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
///
/// **This must be computed by hand, not with `Object.hash`/`Object.hashAll`.**
/// Those are explicitly documented as unstable between runs of a program --
/// Dart randomizes `String.hashCode` per isolate -- so the value they produced
/// for an unchanged schedule differed on every launch. The stored version then
/// failed to match, `ensureDay` re-materialized the day, and every scheduled
/// entry was rebuilt with `eaten: false`: ticking a meal off and restarting
/// silently lost it. A written-out digest is stable across runs, devices, and
/// Dart versions, which is the only reason a value like this can be persisted
/// at all.
int scheduleVersionOf(List<ScheduleItem> items) {
  final sorted = [...items]..sort((a, b) => a.id.compareTo(b.id));
  final canonical = sorted
      .map((item) =>
          '${item.id}|${item.order}|${item.updatedAt.millisecondsSinceEpoch}')
      .join(';');
  return _stableHash(canonical);
}

/// djb2, masked to 32 bits after every step.
///
/// Collision resistance is irrelevant here -- this only has to change when the
/// schedule changes -- but determinism is not, hence rolling it by hand. The
/// masking also keeps every intermediate below 2^53 so the value is identical
/// on the JS number representation as on a native 64-bit int.
int _stableHash(String input) {
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash + unit) & 0xFFFFFFFF;
  }
  return hash;
}
