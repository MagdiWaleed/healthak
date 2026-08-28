import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/schedule/schedule_item.dart';
import 'package:flutter_test/flutter_test.dart';

ScheduleItem _item(String id,
        {int order = 0, DateTime? updatedAt}) =>
    ScheduleItem(
      id: id,
      mealId: 'meal-$id',
      name: id,
      snapshot: const [],
      slot: MealSlot.breakfast,
      order: order,
      daysOfWeek: ScheduleItem.everyDay,
      createdAt: DateTime(2026),
      updatedAt: updatedAt ?? DateTime(2026),
    );

void main() {
  group('scheduleVersionOf', () {
    test('is stable across re-fetching identical content', () {
      final a = [_item('x'), _item('y')];
      final b = [_item('x'), _item('y')];
      expect(scheduleVersionOf(a), scheduleVersionOf(b));
    });

    test('is order-independent in the input list', () {
      final a = [_item('x'), _item('y')];
      final b = [_item('y'), _item('x')];
      expect(scheduleVersionOf(a), scheduleVersionOf(b));
    });

    test('changes when an item is edited in place', () {
      final before = [_item('x', updatedAt: DateTime(2026, 1, 1))];
      final after = [_item('x', updatedAt: DateTime(2026, 1, 2))];
      expect(scheduleVersionOf(before), isNot(scheduleVersionOf(after)));
    });

    test('changes when order changes', () {
      final before = [_item('x', order: 0), _item('y', order: 1)];
      final after = [_item('x', order: 1), _item('y', order: 0)];
      expect(scheduleVersionOf(before), isNot(scheduleVersionOf(after)));
    });

    test('changes when an item is added or removed', () {
      final one = [_item('x')];
      final two = [_item('x'), _item('y')];
      expect(scheduleVersionOf(one), isNot(scheduleVersionOf(two)));
    });

    test('empty schedule has a stable, non-crashing version', () {
      expect(scheduleVersionOf(const []), scheduleVersionOf(const []));
    });
  });
}
