import 'package:diet_app2/domain/meal/meal_definition.dart';
import 'package:diet_app2/domain/meal/meal_entry.dart';
import 'package:diet_app2/domain/meal/meal_math.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:flutter_test/flutter_test.dart';

/// 100 kcal per 100g, all from carbs.
const carb100 = Macros(protein: 0, carbs: 25, fat: 0);

/// 100 kcal per 100g, all from protein.
const protein100 = Macros(protein: 25, carbs: 0, fat: 0);

int _idCounter = 0;
String _nextId() => 'local-${_idCounter++}';

FoodEntry food({
  required String name,
  required double grams,
  Macros per100 = carb100,
  int order = 0,
  String? localId,
}) =>
    FoodEntry(
      localId: localId ?? _nextId(),
      order: order,
      foodId: 'food-$name',
      name: name,
      per100: per100,
      grams: grams,
    );

MealRefEntry mealRef({
  required String mealId,
  required String name,
  double scale = 1.0,
  int order = 0,
  String? localId,
}) =>
    MealRefEntry(
      localId: localId ?? _nextId(),
      order: order,
      mealId: mealId,
      name: name,
      scale: scale,
    );

MealDefinition meal({
  required String id,
  required List<MealEntry> entries,
  String name = 'meal',
  int depth = 0,
  int leafCount = 0,
  Set<String> descendants = const {},
}) =>
    MealDefinition(
      id: id,
      ownerUid: 'uid',
      name: name,
      entries: entries,
      depth: depth,
      leafCount: leafCount,
      descendantMealIds: descendants,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  setUp(() => _idCounter = 0);

  group('macrosOfMeal', () {
    test('sums a flat meal', () {
      final m = meal(id: 'a', entries: [
        food(name: 'rice', grams: 200, order: 0), // 200 kcal
        food(name: 'chicken', grams: 100, per100: protein100, order: 1), // 100
      ]);
      final resolver = MealResolver([m]);

      expect(macrosOfMeal(m, resolver).kcal, closeTo(300, 0.01));
      expect(macrosOfMeal(m, resolver).carbs, closeTo(50, 0.01));
      expect(macrosOfMeal(m, resolver).protein, closeTo(25, 0.01));
    });

    test('an empty meal is zero, not an error', () {
      final m = meal(id: 'a', entries: []);
      expect(macrosOfMeal(m, MealResolver([m])), Macros.zero);
    });

    test('recurses one level through a meal reference', () {
      final inner = meal(id: 'inner', entries: [
        food(name: 'rice', grams: 100), // 100 kcal
      ]);
      final outer = meal(id: 'outer', entries: [
        food(name: 'oil', grams: 100), // 100 kcal
        mealRef(mealId: 'inner', name: 'inner', order: 1),
      ]);

      final resolver = MealResolver([inner, outer]);
      expect(macrosOfMeal(outer, resolver).kcal, closeTo(200, 0.01));
    });

    test('applies the scale factor of a reference', () {
      final inner = meal(id: 'inner', entries: [food(name: 'rice', grams: 100)]);
      final outer = meal(id: 'outer', entries: [
        mealRef(mealId: 'inner', name: 'inner', scale: 0.5),
      ]);

      final resolver = MealResolver([inner, outer]);
      expect(macrosOfMeal(outer, resolver).kcal, closeTo(50, 0.01));
    });

    test('multiplies scales through three levels', () {
      final l3 = meal(id: 'l3', entries: [food(name: 'rice', grams: 100)]);
      final l2 = meal(id: 'l2', entries: [
        mealRef(mealId: 'l3', name: 'l3', scale: 0.5),
      ]);
      final l1 = meal(id: 'l1', entries: [
        mealRef(mealId: 'l2', name: 'l2', scale: 2.0),
      ]);

      final resolver = MealResolver([l1, l2, l3]);
      // 100 kcal * 0.5 * 2.0
      expect(macrosOfMeal(l1, resolver).kcal, closeTo(100, 0.01));
    });

    test('a diamond reference resolves consistently', () {
      final shared = meal(id: 'shared', entries: [food(name: 'rice', grams: 100)]);
      final outer = meal(id: 'outer', entries: [
        mealRef(mealId: 'shared', name: 'shared', order: 0),
        mealRef(mealId: 'shared', name: 'shared', order: 1),
      ]);

      final resolver = MealResolver([shared, outer]);
      expect(macrosOfMeal(outer, resolver).kcal, closeTo(200, 0.01));
    });

    test('throws MealNotFound for a dangling reference', () {
      final outer = meal(id: 'outer', entries: [
        mealRef(mealId: 'missing', name: 'gone'),
      ]);
      expect(
        () => macrosOfMeal(outer, MealResolver([outer])),
        throwsA(isA<MealNotFound>()),
      );
    });

    test('throws MealCycleException rather than overflowing the stack', () {
      // Only reachable if data is corrupted out of band -- canNest prevents it.
      final a = meal(id: 'a', entries: [mealRef(mealId: 'b', name: 'b')]);
      final b = meal(id: 'b', entries: [mealRef(mealId: 'a', name: 'a')]);

      expect(
        () => macrosOfMeal(a, MealResolver([a, b])),
        throwsA(isA<MealCycleException>()),
      );
    });
  });

  group('depthOfMeal', () {
    test('a flat meal has depth 0', () {
      final m = meal(id: 'a', entries: [food(name: 'rice', grams: 100)]);
      expect(depthOfMeal(m, MealResolver([m])), 0);
    });

    test('counts nesting levels', () {
      final l3 = meal(id: 'l3', entries: [food(name: 'rice', grams: 100)]);
      final l2 = meal(id: 'l2', entries: [mealRef(mealId: 'l3', name: 'l3')]);
      final l1 = meal(id: 'l1', entries: [mealRef(mealId: 'l2', name: 'l2')]);

      final resolver = MealResolver([l1, l2, l3]);
      expect(depthOfMeal(l3, resolver), 0);
      expect(depthOfMeal(l2, resolver), 1);
      expect(depthOfMeal(l1, resolver), 2);
    });
  });

  group('descendantMealIdsOf', () {
    test('is empty for a flat meal', () {
      final m = meal(id: 'a', entries: [food(name: 'rice', grams: 100)]);
      expect(descendantMealIdsOf(m, MealResolver([m])), isEmpty);
    });

    test('collects transitively', () {
      final l3 = meal(id: 'l3', entries: [food(name: 'rice', grams: 100)]);
      final l2 = meal(id: 'l2', entries: [mealRef(mealId: 'l3', name: 'l3')]);
      final l1 = meal(id: 'l1', entries: [mealRef(mealId: 'l2', name: 'l2')]);

      final ids = descendantMealIdsOf(l1, MealResolver([l1, l2, l3]));
      expect(ids, {'l2', 'l3'});
    });
  });

  group('canNest', () {
    final resolver = MealResolver(const <MealDefinition>[]);

    test('refuses a meal inside itself', () {
      final m = meal(id: 'a', entries: []);
      final check = canNest(parent: m, child: m, resolver: resolver);

      expect(check.allowed, isFalse);
      expect(check.refusal, NestRefusal.self);
      expect(check.messageAr, isNotEmpty);
    });

    test('refuses when the child already contains the parent', () {
      final parent = meal(id: 'a', entries: []);
      final child = meal(id: 'b', entries: [], descendants: {'a'});

      final check = canNest(parent: parent, child: child, resolver: resolver);
      expect(check.allowed, isFalse);
      expect(check.refusal, NestRefusal.cycle);
    });

    test('allows an unrelated meal', () {
      final parent = meal(id: 'a', entries: [], leafCount: 3);
      final child = meal(id: 'b', entries: [], leafCount: 2);

      expect(canNest(parent: parent, child: child, resolver: resolver).allowed,
          isTrue);
    });

    test('refuses when the result would exceed the depth limit', () {
      final parent = meal(id: 'a', entries: [], depth: kMaxNestDepth);
      final child = meal(id: 'b', entries: [], depth: kMaxNestDepth);

      final check = canNest(parent: parent, child: child, resolver: resolver);
      expect(check.allowed, isFalse);
      expect(check.refusal, NestRefusal.depth);
    });

    test('refuses when the result would exceed the leaf limit', () {
      final parent = meal(id: 'a', entries: [], leafCount: kMaxLeafCount);
      final child = meal(id: 'b', entries: [], leafCount: 5);

      final check = canNest(parent: parent, child: child, resolver: resolver);
      expect(check.allowed, isFalse);
      expect(check.refusal, NestRefusal.leafCount);
    });

    test('every refusal carries an Arabic message', () {
      for (final refusal in NestRefusal.values) {
        expect(refusal.messageAr, isNotEmpty);
      }
    });
  });

  group('flattenMeal', () {
    test('a flat meal passes through unchanged', () {
      final m = meal(id: 'a', entries: [
        food(name: 'rice', grams: 100, order: 0),
        food(name: 'oil', grams: 20, order: 1),
      ]);

      final flat = flattenMeal(m, MealResolver([m]));
      expect(flat, hasLength(2));
      expect(flat.map((f) => f.name), ['rice', 'oil']);
      expect(flat.every((f) => f.groupLabel == null), isTrue);
    });

    test('collapses nesting and labels the leaves with their group', () {
      final inner = meal(
        id: 'inner',
        name: 'breakfast',
        entries: [food(name: 'egg', grams: 100)],
      );
      final outer = meal(id: 'outer', entries: [
        food(name: 'rice', grams: 100, order: 0),
        mealRef(mealId: 'inner', name: 'breakfast', order: 1),
      ]);

      final flat = flattenMeal(outer, MealResolver([inner, outer]));
      expect(flat, hasLength(2));
      expect(flat[0].groupLabel, isNull);
      expect(flat[1].name, 'egg');
      expect(flat[1].groupLabel, 'breakfast');
    });

    test('multiplies grams by the scale chain', () {
      final inner = meal(id: 'inner', entries: [food(name: 'egg', grams: 100)]);
      final outer = meal(id: 'outer', entries: [
        mealRef(mealId: 'inner', name: 'inner', scale: 0.5),
      ]);

      final flat = flattenMeal(outer, MealResolver([inner, outer]));
      expect(flat.single.grams, closeTo(50, 0.01));
    });

    test('conserves total macros', () {
      final inner = meal(id: 'inner', entries: [
        food(name: 'egg', grams: 100, per100: protein100),
      ]);
      final outer = meal(id: 'outer', entries: [
        food(name: 'rice', grams: 150, order: 0),
        mealRef(mealId: 'inner', name: 'inner', scale: 0.5, order: 1),
      ]);

      final resolver = MealResolver([inner, outer]);
      final recursive = macrosOfMeal(outer, resolver);
      final flattened = flattenMeal(outer, resolver)
          .fold(Macros.zero, (Macros a, f) => a + f.macros);

      expect(flattened.kcal, closeTo(recursive.kcal, 0.01));
      expect(flattened.protein, closeTo(recursive.protein, 0.01));
      expect(flattened.carbs, closeTo(recursive.carbs, 0.01));
    });

    test('leafCountOfMeal counts through nesting', () {
      final inner = meal(id: 'inner', entries: [
        food(name: 'egg', grams: 100, order: 0),
        food(name: 'oil', grams: 10, order: 1),
      ]);
      final outer = meal(id: 'outer', entries: [
        food(name: 'rice', grams: 100, order: 0),
        mealRef(mealId: 'inner', name: 'inner', order: 1),
      ]);

      expect(leafCountOfMeal(outer, MealResolver([inner, outer])), 3);
    });
  });

  group('ungroupEntry', () {
    test('replaces a reference with its scaled leaves', () {
      final inner = meal(id: 'inner', entries: [
        food(name: 'egg', grams: 100, per100: protein100, order: 0),
        food(name: 'oil', grams: 20, order: 1),
      ]);
      final ref = mealRef(
        mealId: 'inner',
        name: 'inner',
        scale: 0.5,
        order: 1,
        localId: 'the-ref',
      );
      final entries = [food(name: 'rice', grams: 100, order: 0), ref];

      var counter = 100;
      final result = ungroupEntry(
        entries: entries,
        localId: 'the-ref',
        resolver: MealResolver([inner]),
        newLocalId: () => 'new-${counter++}',
      );

      expect(result, hasLength(3));
      expect(result.every((e) => e is FoodEntry), isTrue);
      expect(result.map((e) => e.name), ['rice', 'egg', 'oil']);
      expect((result[1] as FoodEntry).grams, closeTo(50, 0.01));
      expect((result[2] as FoodEntry).grams, closeTo(10, 0.01));
    });

    test('conserves total macros', () {
      final inner = meal(id: 'inner', entries: [
        food(name: 'egg', grams: 100, per100: protein100),
      ]);
      final ref = mealRef(
          mealId: 'inner', name: 'inner', scale: 0.5, localId: 'the-ref');
      final entries = [ref];

      final before = (macrosOfMeal(
        meal(id: 'tmp', entries: entries),
        MealResolver([inner]),
      ));

      var counter = 0;
      final after = ungroupEntry(
        entries: entries,
        localId: 'the-ref',
        resolver: MealResolver([inner]),
        newLocalId: () => 'n${counter++}',
      ).whereType<FoodEntry>().fold(Macros.zero, (Macros a, e) => a + e.macros);

      expect(after.kcal, closeTo(before.kcal, 0.01));
      expect(after.protein, closeTo(before.protein, 0.01));
    });

    test('renumbers order after expanding', () {
      final inner = meal(id: 'inner', entries: [
        food(name: 'egg', grams: 100, order: 0),
        food(name: 'oil', grams: 20, order: 1),
      ]);
      final entries = [
        food(name: 'rice', grams: 100, order: 0),
        mealRef(mealId: 'inner', name: 'inner', order: 1, localId: 'the-ref'),
        food(name: 'salt', grams: 5, order: 2),
      ];

      var counter = 0;
      final result = ungroupEntry(
        entries: entries,
        localId: 'the-ref',
        resolver: MealResolver([inner]),
        newLocalId: () => 'n${counter++}',
      );

      expect(result.map((e) => e.order), [0, 1, 2, 3]);
    });

    test('is a no-op for an unknown localId', () {
      final entries = [food(name: 'rice', grams: 100)];
      final result = ungroupEntry(
        entries: entries,
        localId: 'nope',
        resolver: MealResolver(const []),
        newLocalId: () => 'x',
      );
      expect(result, same(entries));
    });

    test('is a no-op when the target is a food, not a reference', () {
      final entries = [food(name: 'rice', grams: 100, localId: 'f1')];
      final result = ungroupEntry(
        entries: entries,
        localId: 'f1',
        resolver: MealResolver(const []),
        newLocalId: () => 'x',
      );
      expect(result, same(entries));
    });
  });

  group('renumber', () {
    test('rewrites order to match position and keeps localId stable', () {
      final entries = [
        food(name: 'a', grams: 1, order: 7, localId: 'x'),
        food(name: 'b', grams: 1, order: 3, localId: 'y'),
      ];

      final result = renumber(entries);
      expect(result.map((e) => e.order), [0, 1]);
      // Identity survives reordering -- the old code addressed by index.
      expect(result.map((e) => e.localId), ['x', 'y']);
    });
  });

  group('withRecomputedCaches', () {
    test('fills totals, depth, leafCount and descendants together', () {
      final inner = meal(id: 'inner', entries: [
        food(name: 'egg', grams: 100, per100: protein100),
      ]);
      final outer = meal(id: 'outer', entries: [
        food(name: 'rice', grams: 100, order: 0),
        mealRef(mealId: 'inner', name: 'inner', order: 1),
      ]);

      final result =
          withRecomputedCaches(outer, MealResolver([inner, outer]));

      expect(result.totalsCache.kcal, closeTo(200, 0.01));
      expect(result.depth, 1);
      expect(result.leafCount, 2);
      expect(result.descendantMealIds, {'inner'});
    });
  });
}
