import '../../data/repositories/day_repository.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/meal_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/food/food_item.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/profile/user_profile.dart';

abstract interface class AgentDataSource {
  Future<DayLog?> getDay(DateTime date);
  Future<List<DayLog>> getHistory(DateTime start, DateTime end);
  Future<UserProfile?> getProfile();
  Future<List<MealDefinition>> getMeals();
  Future<List<FoodItem>> searchFoods(String query);
}

class HealthakAgentDataSource implements AgentDataSource {
  final String uid;
  final DayRepository _days;
  final FoodRepository _foods;
  final MealRepository _meals;
  final ProfileRepository _profiles;

  HealthakAgentDataSource({
    required this.uid,
    DayRepository? days,
    FoodRepository? foods,
    MealRepository? meals,
    ProfileRepository? profiles,
  })  : _days = days ?? DayRepository(uid: uid),
        _foods = foods ?? FoodRepository(uid: uid),
        _meals = meals ?? MealRepository(uid: uid),
        _profiles = profiles ?? ProfileRepository();

  @override
  Future<DayLog?> getDay(DateTime date) => _days.get(date);

  @override
  Future<List<DayLog>> getHistory(DateTime start, DateTime end) =>
      _days.getRange(start, end);

  @override
  Future<UserProfile?> getProfile() => _profiles.get(uid);

  @override
  Future<List<MealDefinition>> getMeals() => _meals.getAll();

  @override
  Future<List<FoodItem>> searchFoods(String query) async {
    final normalized = foldArabic(query);
    final personal = await _foods.listPersonal();
    final localMatches = personal
        .where((food) => foldArabic(food.name).contains(normalized))
        .toList(growable: false);
    final shared = await _foods.list(searchToken: query);
    return [...localMatches, ...shared.items];
  }
}
