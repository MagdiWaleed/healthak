import '../../data/repositories/day_repository.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/meal_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/food/food_item.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/nutrition/energy.dart';
import '../../domain/profile/user_profile.dart';

abstract interface class AgentDataSource {
  String get uid;

  Future<DayLog?> getDay(DateTime date);
  Future<DayLog?> getDayByKey(String dateKey);
  Future<List<DayLog>> getHistory(DateTime start, DateTime end);
  Future<UserProfile?> getProfile();
  Future<List<MealDefinition>> getMeals();
  Future<List<FoodItem>> searchFoods(String query);

  /// Every personal component, unfiltered -- used to precall the model's
  /// context with real ids so it never needs to guess or search for
  /// something it already owns.
  Future<List<FoodItem>> getPersonalFoods();

  /// Materializes today's day document if it doesn't exist yet -- a write
  /// tool can be the very first thing that touches today, before the Today
  /// tab ever opens.
  Future<DayLog> ensureDay(DateTime date, NutritionTargets targets);

  Future<void> upsertDayEntry(String dateKey, DayEntry entry);
  Future<void> removeDayEntry(String dateKey, String entryId);

  Future<FoodItem?> getFoodById(String id);

  /// Writes a new personal component (never the shared catalog) and returns
  /// it with its assigned id.
  Future<FoodItem> createPersonalFood(FoodItem draft);

  Future<MealDefinition?> getMealById(String id);
  Future<MealDefinition> saveMeal(MealDefinition draft);
  Future<void> deleteMeal(String id);
}

class HealthakAgentDataSource implements AgentDataSource {
  @override
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
  Future<DayLog?> getDayByKey(String dateKey) =>
      _days.get(DateTime.parse(dateKey));

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

  @override
  Future<List<FoodItem>> getPersonalFoods() => _foods.listPersonal();

  @override
  Future<DayLog> ensureDay(DateTime date, NutritionTargets targets) =>
      _days.ensureDay(date: date, targets: targets);

  @override
  Future<void> upsertDayEntry(String dateKey, DayEntry entry) =>
      _days.upsertEntry(dateKey, entry);

  @override
  Future<void> removeDayEntry(String dateKey, String entryId) =>
      _days.removeEntry(dateKey, entryId);

  @override
  Future<FoodItem?> getFoodById(String id) async {
    // Shared catalog first (the common case, one read). Falls back to the
    // user's personal components -- e.g. one search_food_online just
    // created -- which live in a different collection with no by-id lookup
    // of their own, same as searchFoods above.
    final shared = await _foods.getById(id);
    if (shared != null) return shared;
    final personal = await _foods.listPersonal();
    for (final food in personal) {
      if (food.id == id) return food;
    }
    return null;
  }

  @override
  Future<FoodItem> createPersonalFood(FoodItem draft) =>
      _foods.createPersonal(draft);

  @override
  Future<MealDefinition?> getMealById(String id) => _meals.get(id);

  @override
  Future<MealDefinition> saveMeal(MealDefinition draft) => _meals.save(draft);

  @override
  Future<void> deleteMeal(String id) => _meals.delete(id);
}
