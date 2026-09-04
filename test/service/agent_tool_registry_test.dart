import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/food/food_item.dart';
import 'package:diet_app2/domain/meal/meal_definition.dart';
import 'package:diet_app2/domain/meal/meal_entry.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/service/agent/agent_data_source.dart';
import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/agent_proposal.dart';
import 'package:diet_app2/service/agent/agent_tool_registry.dart';
import 'package:diet_app2/service/agent/web_food_search_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentToolRegistry read tools', () {
    test('exposes the seven read tools plus the seven propose tools', () {
      final registry = AgentToolRegistry(data: _FakeData());

      expect(
        registry.definitions.map((tool) => tool.name),
        containsAll(<String>[
          'get_today',
          'get_history_range',
          'get_profile',
          'get_meals',
          'search_foods',
          'get_remaining_targets',
          'search_food_online',
          'propose_log_food',
          'propose_log_meal',
          'propose_swap_meal',
          'propose_update_grams',
          'propose_remove_entry',
          'propose_create_meal',
          'propose_log_custom_component',
        ]),
      );
      expect(registry.definitions, hasLength(14));
    });

    test('search_food_online is refused when no search client is configured',
        () async {
      final registry = AgentToolRegistry(data: _FakeData());

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'search_food_online',
        arguments: {'query': 'dragon fruit'},
      ));

      expect(result.isError, isTrue);
      expect(result.data['error'], 'search_unavailable');
    });

    test('search_food_online returns grounded text and sources', () async {
      final registry = AgentToolRegistry(
        data: _FakeData(),
        webSearch: _FakeWebSearch(),
      );

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'search_food_online',
        arguments: {'query': 'dragon fruit'},
      ));

      expect(result.isError, isFalse);
      expect(result.data['source'], 'web');
      expect(result.data['text'], contains('60 kcal'));
      expect(result.data['sources'], isNotEmpty);
    });

    test('recomputes meal totals instead of trusting totalsCache', () async {
      final meal = MealDefinition(
        id: 'meal-1',
        ownerUid: 'user-1',
        name: 'وجبة الاختبار',
        entries: const [
          FoodEntry(
            localId: 'entry-1',
            order: 0,
            foodId: 'food-1',
            name: 'أرز',
            per100: Macros(protein: 2, carbs: 25, fat: 1),
            grams: 200,
          ),
        ],
        totalsCache: const Macros(protein: 999, carbs: 999, fat: 999),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final registry = AgentToolRegistry(data: _FakeData(meals: [meal]));

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'get_meals',
        arguments: {},
      ));

      final meals = result.data['meals'] as List<dynamic>;
      final totals = (meals.single as Map<String, dynamic>)['totals']
          as Map<String, dynamic>;
      expect(totals['protein_g'], 4);
      expect(totals['carbs_g'], 50);
      expect(totals['fat_g'], 2);
      expect(totals['kcal'], 234);
    });

    test('rejects invalid food searches before reading data', () async {
      final data = _FakeData();
      final registry = AgentToolRegistry(data: data);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'search_foods',
        arguments: {'query': 'ا'},
      ));

      expect(result.isError, isTrue);
      expect(result.data['error'], 'query_too_short');
      expect(data.searchCount, 0);
    });

    test('executes every planned read tool against grounded data', () async {
      final targets = NutritionTargets.manual(
        kcal: 2000,
        macros: const Macros(protein: 150, carbs: 200, fat: 66.6666667),
      );
      final today = DayLog.empty(DateTime(2026, 9, 4), targets);
      final profile = UserProfile(
        uid: 'user-1',
        displayName: 'مجد',
        email: 'private@example.com',
        sex: Sex.male,
        birthYear: 1995,
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        weeklyRateKg: 0,
        targets: targets,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      const food = FoodItem(
        id: 'food-1',
        name: 'أرز',
        category: 'حبوب',
        per100: Macros(protein: 2, carbs: 25, fat: 1),
      );
      final registry = AgentToolRegistry(
        data: _FakeData(
          day: today,
          history: [today],
          profile: profile,
          foods: [food],
        ),
        now: () => DateTime(2026, 9, 4),
      );

      final cases = <String, Map<String, dynamic>>{
        'get_today': {},
        'get_history_range': {'days': 1},
        'get_profile': {},
        'get_meals': {},
        'search_foods': {'query': 'أرز'},
        'get_remaining_targets': {},
      };
      for (final entry in cases.entries) {
        final result = await registry.run(AgentToolCall(
          id: 'call-${entry.key}',
          name: entry.key,
          arguments: entry.value,
        ));
        expect(result.isError, isFalse, reason: entry.key);
      }
      final profileResult = await registry.run(const AgentToolCall(
        id: 'profile',
        name: 'get_profile',
        arguments: {},
      ));
      expect(profileResult.data, isNot(contains('email')));
    });
  });

  group('AgentToolRegistry write tools', () {
    const food = FoodItem(
      id: 'food-1',
      name: 'صدر دجاج',
      per100: Macros(protein: 31, carbs: 0, fat: 3.6),
    );
    final targets = NutritionTargets.manual(
      kcal: 2000,
      macros: const Macros(protein: 150, carbs: 200, fat: 66),
    );
    final now = DateTime(2026, 9, 4, 13);

    test('propose_log_food resolves the real food and clamps grams', () async {
      final data = _FakeData(
        day: DayLog.empty(DateTime(2026, 9, 4), targets),
        foods: [food],
      );
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_log_food',
        arguments: {'food_id': 'food-1', 'grams': 5000},
      ));

      expect(result.isError, isFalse);
      final proposal = result.proposal!;
      expect(proposal.kind, ProposalKind.logFood);
      expect(proposal.card['grams'], 2000); // clamped
      expect((proposal.card['macros'] as Map)['kcal'], food.per100.forGrams(2000).kcal);
    });

    test('unknown food_id is rejected before any proposal is built', () async {
      final data = _FakeData(day: DayLog.empty(DateTime(2026, 9, 4), targets));
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_log_food',
        arguments: {'food_id': 'ghost', 'grams': 150},
      ));

      expect(result.isError, isTrue);
      expect(result.data['error'], 'food_not_found');
      expect(result.proposal, isNull);
    });

    test('confirming propose_log_food writes the entry and undo removes it',
        () async {
      final data = _FakeData(
        day: DayLog.empty(DateTime(2026, 9, 4), targets),
        foods: [food],
      );
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_log_food',
        arguments: {'food_id': 'food-1', 'grams': 150, 'slot': 'lunch'},
      ));
      final receipt = await registry.confirm(result.proposal!);

      expect(data.day!.entries, hasLength(1));
      expect(data.day!.entries.single.name, 'صدر دجاج');
      expect(data.day!.entries.single.slot, MealSlot.lunch);
      expect(receipt.isUndoable, isTrue);

      await registry.undo(receipt);
      expect(data.day!.entries, isEmpty);
    });

    test('propose_remove_entry on an unknown id is rejected', () async {
      final data = _FakeData(day: DayLog.empty(DateTime(2026, 9, 4), targets));
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_remove_entry',
        arguments: {'entry_id': 'ghost'},
      ));

      expect(result.isError, isTrue);
      expect(result.data['error'], 'entry_not_found');
    });

    test('propose_update_grams scales every item proportionally', () async {
      var day = DayLog.empty(DateTime(2026, 9, 4), targets);
      day = day.withEntry(DayEntry(
        entryId: 'e1',
        origin: DayEntryOrigin.quickAdd,
        name: 'صدر دجاج',
        slot: MealSlot.lunch,
        order: 0,
        items: [
          FrozenItem(foodId: 'food-1', name: 'صدر دجاج', per100: food.per100, grams: 100),
        ],
      ));
      final data = _FakeData(day: day);
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_update_grams',
        arguments: {'entry_id': 'e1', 'new_grams': 200},
      ));
      final receipt = await registry.confirm(result.proposal!);

      expect(data.day!.entries.single.items.single.grams, 200);
      await registry.undo(receipt);
      expect(data.day!.entries.single.items.single.grams, 100);
    });

    test('confirm refuses a stale proposal when the entry changed underneath it',
        () async {
      var day = DayLog.empty(DateTime(2026, 9, 4), targets);
      day = day.withEntry(DayEntry(
        entryId: 'e1',
        origin: DayEntryOrigin.quickAdd,
        name: 'صدر دجاج',
        slot: MealSlot.lunch,
        order: 0,
        items: [
          FrozenItem(foodId: 'food-1', name: 'صدر دجاج', per100: food.per100, grams: 100),
        ],
      ));
      final data = _FakeData(day: day);
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_remove_entry',
        arguments: {'entry_id': 'e1'},
      ));

      // The entry's weight changes after the proposal was built but before
      // it's confirmed -- e.g. the user edited it by hand in Today.
      data.day = data.day!.withEntry(
        data.day!.entries.single.copyWith(items: [
          FrozenItem(foodId: 'food-1', name: 'صدر دجاج', per100: food.per100, grams: 250),
        ]),
      );

      expect(
        () => registry.confirm(result.proposal!),
        throwsA(isA<AgentProposalStaleException>()),
      );
    });

    test('propose_swap_meal computes the macro delta and swaps on confirm',
        () async {
      var day = DayLog.empty(DateTime(2026, 9, 4), targets);
      day = day.withEntry(DayEntry(
        entryId: 'e1',
        origin: DayEntryOrigin.oneShot,
        sourceMealId: 'meal-old',
        name: 'وجبة قديمة',
        slot: MealSlot.lunch,
        order: 0,
        items: [
          FrozenItem(foodId: 'food-1', name: 'صدر دجاج', per100: food.per100, grams: 100),
        ],
      ));
      final newMeal = MealDefinition(
        id: 'meal-new',
        ownerUid: 'user-1',
        name: 'وجبة جديدة',
        entries: [
          FoodEntry(
            localId: 'x',
            order: 0,
            foodId: 'food-1',
            name: 'صدر دجاج',
            per100: food.per100,
            grams: 300,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final data = _FakeData(day: day, meals: [newMeal]);
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_swap_meal',
        arguments: {'entry_id': 'e1', 'new_meal_id': 'meal-new'},
      ));
      expect(result.isError, isFalse);
      final delta = (result.proposal!.card['delta'] as Map)['kcal'] as num;
      expect(delta, greaterThan(0)); // 300g logged over 100g

      final receipt = await registry.confirm(result.proposal!);
      expect(data.day!.entries, hasLength(1));
      expect(data.day!.entries.single.name, 'وجبة جديدة');
      expect(data.day!.entries.single.items.single.grams, 300);

      await registry.undo(receipt);
      expect(data.day!.entries.single.name, 'وجبة قديمة');
      expect(data.day!.entries.single.items.single.grams, 100);
    });

    test('propose_create_meal only accepts real catalog foods and saves on confirm',
        () async {
      final data = _FakeData(foods: [food]);
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_create_meal',
        arguments: {
          'name': 'وجبتي الجديدة',
          'entries': [
            {'food_id': 'food-1', 'grams': 150},
          ],
        },
      ));
      expect(result.isError, isFalse);
      final receipt = await registry.confirm(result.proposal!);

      expect(data.meals.values.map((m) => m.name), contains('وجبتي الجديدة'));
      await registry.undo(receipt);
      expect(data.meals.values.map((m) => m.name), isNot(contains('وجبتي الجديدة')));
    });

    test('propose_log_food resolves a personal (not just shared) food by id',
        () async {
      const personalFood = FoodItem(
        id: 'personal-1',
        name: 'فاكهة التنين',
        per100: Macros(protein: 1, carbs: 16, fat: 0.2),
      );
      final data = _FakeData(
        day: DayLog.empty(DateTime(2026, 9, 4), targets),
        foods: [personalFood],
      );
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_log_food',
        arguments: {'food_id': 'personal-1', 'grams': 150},
      ));

      expect(result.isError, isFalse);
      expect(result.proposal!.card['name'], 'فاكهة التنين');
    });

    test('buildKnownCatalogContext lists personal foods and meals with real ids',
        () async {
      const personalFood = FoodItem(
        id: 'personal-1',
        name: 'فاكهة التنين',
        per100: Macros(protein: 1, carbs: 16, fat: 0.2),
      );
      final meal = MealDefinition(
        id: 'meal-1',
        ownerUid: 'user-1',
        name: 'وجبة الاختبار',
        entries: const [],
        createdAt: now,
        updatedAt: now,
      );
      final registry = AgentToolRegistry(
        data: _FakeData(foods: [personalFood], meals: [meal]),
      );

      final context = await registry.buildKnownCatalogContext();

      expect(context, contains('فاكهة التنين'));
      expect(context, contains('personal-1'));
      expect(context, contains('وجبة الاختبار'));
      expect(context, contains('meal-1'));
    });

    test('buildKnownCatalogContext is empty when the user owns nothing yet',
        () async {
      final registry = AgentToolRegistry(data: _FakeData());

      expect(await registry.buildKnownCatalogContext(), isEmpty);
    });

    test('propose_log_custom_component creates a personal food marked estimated',
        () async {
      final data = _FakeData(day: DayLog.empty(DateTime(2026, 9, 4), targets));
      final registry = AgentToolRegistry(data: data, now: () => now);

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_log_custom_component',
        arguments: {
          'name': 'أكلة بيتية',
          'protein_per_100': 10,
          'carbs_per_100': 20,
          'fat_per_100': 5,
          'grams': 200,
        },
      ));
      expect(result.isError, isFalse);
      expect(result.proposal!.card['estimated'], isTrue);

      await registry.confirm(result.proposal!);
      expect(data.day!.entries.single.name, 'أكلة بيتية');
      expect(data.foods.values.any((f) => f.note != null), isTrue);
    });
  });
}

class _FakeData implements AgentDataSource {
  @override
  final String uid = 'user-1';
  final Map<String, MealDefinition> meals;
  final Map<String, FoodItem> foods;
  DayLog? day;
  final List<DayLog> history;
  final UserProfile? profile;
  int searchCount = 0;
  int _foodSeq = 0;

  _FakeData({
    List<MealDefinition> meals = const [],
    this.day,
    this.history = const [],
    this.profile,
    List<FoodItem> foods = const [],
  })  : meals = {for (final m in meals) m.id: m},
        foods = {for (final f in foods) f.id: f};

  @override
  Future<DayLog?> getDay(DateTime date) async => day;

  @override
  Future<DayLog?> getDayByKey(String dateKey) async =>
      day?.dateKey == dateKey ? day : null;

  @override
  Future<List<DayLog>> getHistory(DateTime start, DateTime end) async =>
      history;

  @override
  Future<List<MealDefinition>> getMeals() async => meals.values.toList();

  @override
  Future<UserProfile?> getProfile() async => profile;

  @override
  Future<List<FoodItem>> searchFoods(String query) async {
    searchCount++;
    return foods.values.toList();
  }

  @override
  Future<List<FoodItem>> getPersonalFoods() async => foods.values.toList();

  @override
  Future<DayLog> ensureDay(DateTime date, NutritionTargets targets) async {
    day ??= DayLog.empty(date, targets);
    return day!;
  }

  @override
  Future<void> upsertDayEntry(String dateKey, DayEntry entry) async {
    final current = day;
    if (current == null || current.dateKey != dateKey) {
      throw StateError('Day $dateKey does not exist');
    }
    day = current.withEntry(entry);
  }

  @override
  Future<void> removeDayEntry(String dateKey, String entryId) async {
    final current = day;
    if (current == null) return;
    day = current.withoutEntry(entryId);
  }

  @override
  Future<FoodItem?> getFoodById(String id) async => foods[id];

  @override
  Future<FoodItem> createPersonalFood(FoodItem draft) async {
    _foodSeq++;
    final created = draft.withId('personal-$_foodSeq');
    foods[created.id] = created;
    return created;
  }

  @override
  Future<MealDefinition?> getMealById(String id) async => meals[id];

  @override
  Future<MealDefinition> saveMeal(MealDefinition draft) async {
    meals[draft.id] = draft;
    return draft;
  }

  @override
  Future<void> deleteMeal(String id) async => meals.remove(id);
}

class _FakeWebSearch implements WebFoodSearchClient {
  @override
  Future<WebFoodSearchResult> search(String query) async =>
      const WebFoodSearchResult(
        text: 'Per 100g dragon fruit: ~60 kcal, 0.5g protein, 15g carbs, 0.2g fat.',
        sources: ['https://example.com/dragon-fruit'],
      );
}
