import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/food/food_item.dart';
import 'package:diet_app2/domain/meal/meal_definition.dart';
import 'package:diet_app2/domain/meal/meal_entry.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/service/agent/agent_data_source.dart';
import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/agent_tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentToolRegistry', () {
    test('exposes only the six planned read tools', () {
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
        ]),
      );
      expect(registry.definitions, hasLength(6));
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
}

class _FakeData implements AgentDataSource {
  final List<MealDefinition> meals;
  final DayLog? day;
  final List<DayLog> history;
  final UserProfile? profile;
  final List<FoodItem> foods;
  int searchCount = 0;

  _FakeData({
    this.meals = const [],
    this.day,
    this.history = const [],
    this.profile,
    this.foods = const [],
  });

  @override
  Future<DayLog?> getDay(DateTime date) async => day;

  @override
  Future<List<DayLog>> getHistory(DateTime start, DateTime end) async =>
      history;

  @override
  Future<List<MealDefinition>> getMeals() async => meals;

  @override
  Future<UserProfile?> getProfile() async => profile;

  @override
  Future<List<FoodItem>> searchFoods(String query) async {
    searchCount++;
    return foods;
  }
}
