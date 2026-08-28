import 'package:get/get.dart';

import '../../data/repositories/day_repository.dart';
import '../../domain/day/day_log.dart';

/// Backs the History screen: a month at a time, fetched as one range query.
///
/// Deliberately lean -- per Step 2's own risk notes, the calendar and
/// read-only day detail are the load-bearing part; a kcal trend line and
/// bodyweight logging are left for Step 4. See PROGRESS.md.
class HistoryController extends GetxController {
  final String uid;
  final DayRepository _days;

  HistoryController({required this.uid, DayRepository? days})
      : _days = days ?? DayRepository(uid: uid);

  final month = DateTime(DateTime.now().year, DateTime.now().month).obs;
  final loading = true.obs;

  /// Keyed by `dateKey`, so a lookup for one calendar cell is O(1).
  final days = <String, DayLog>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    loading.value = true;
    final start = month.value;
    final end = DateTime(start.year, start.month + 1, 0); // last day of month
    final result = await _days.getRange(start, end);
    days.value = {for (final day in result) day.dateKey: day};
    loading.value = false;
  }

  void previousMonth() {
    month.value = DateTime(month.value.year, month.value.month - 1);
    _load();
  }

  void nextMonth() {
    final next = DateTime(month.value.year, month.value.month + 1);
    if (next.isAfter(DateTime(DateTime.now().year, DateTime.now().month))) {
      return; // no browsing into a future that can't have data yet
    }
    month.value = next;
    _load();
  }

  DayLog? dayFor(DateTime date) => days[DayLog.keyFor(date)];

  /// 0..1+ adherence for tinting a calendar cell, or null if the day has no
  /// data at all (never opened, nothing logged).
  double? adherenceFor(DateTime date) {
    final day = dayFor(date);
    if (day == null || day.isEmpty) return null;
    return day.progress;
  }
}
