import '../../data/repositories/day_repository.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/meal_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/food/food_item.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/nutrition/energy.dart';
import '../../domain/profile/user_profile.dart';
import '../../domain/body/body_weight.dart';
import '../../domain/training/training_day.dart';
import '../../domain/training/workout_plan_item.dart';
import '../../data/repositories/body_weight_repository.dart';
import '../../data/repositories/training_day_repository.dart';
import '../../data/repositories/workout_plan_repository.dart';
import '../weigh_in_service.dart';

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

/// Optional capability kept separate so existing nutrition data source fakes
/// continue to model only their original contract.
abstract interface class AgentWeightTrainingDataSource {
  Future<List<BodyWeightEntry>> getWeightHistory(DateTime from, DateTime to);
  Future<BodyWeightEntry?> getWeight(DateTime date);
  Future<void> logWeight(DateTime date, double kg);
  Future<void> deleteWeight(DateTime date);
  Future<List<WorkoutPlanItem>> getWorkoutPlan();
  Future<TrainingDay> getTrainingDay(DateTime date);
  Future<void> toggleExercise(DateTime date, String localId);
  Future<void> savePlanItem(WorkoutPlanItem item);
  Future<void> deletePlanItem(String id);
}

class HealthakAgentDataSource
    implements AgentDataSource, AgentWeightTrainingDataSource {
  @override
  final String uid;
  final DayRepository _days;
  final FoodRepository _foods;
  final MealRepository _meals;
  final ProfileRepository _profiles;
  final BodyWeightRepository _weights;
  final WorkoutPlanRepository _plan;
  final TrainingDayRepository _training;
  late final WeighInService _weighIn;

  HealthakAgentDataSource({
    required this.uid,
    DayRepository? days,
    FoodRepository? foods,
    MealRepository? meals,
    ProfileRepository? profiles,
    BodyWeightRepository? weights,
    WorkoutPlanRepository? plan,
    TrainingDayRepository? training,
    WeighInService? weighIn,
  })  : _days = days ?? DayRepository(uid: uid),
        _foods = foods ?? FoodRepository(uid: uid),
        _meals = meals ?? MealRepository(uid: uid),
        _profiles = profiles ?? ProfileRepository(),
        _weights = weights ?? BodyWeightRepository(uid: uid),
        _plan = plan ?? WorkoutPlanRepository(uid: uid),
        _training = training ?? TrainingDayRepository(uid: uid) {
    _weighIn =
        weighIn ?? WeighInService(weights: _weights, profiles: _profiles);
  }

  @override
  Future<List<BodyWeightEntry>> getWeightHistory(DateTime from, DateTime to) =>
      _weights.watchRange(from, to).first;
  @override
  Future<BodyWeightEntry?> getWeight(DateTime date) => _weights.get(date);
  @override
  Future<void> logWeight(DateTime date, double kg) =>
      _weighIn.logWeight(date: date, kg: kg);
  @override
  Future<void> deleteWeight(DateTime date) =>
      _weights.delete(DayLog.keyFor(date));
  @override
  Future<List<WorkoutPlanItem>> getWorkoutPlan() => _plan.getAll();
  @override
  Future<TrainingDay> getTrainingDay(DateTime date) async {
    final existing = await _training.watch(date).first;
    if (existing != null) return existing;
    return _training.ensureTrainingDay(date, await _plan.getAll());
  }

  @override
  Future<void> toggleExercise(DateTime date, String localId) async {
    await _training.ensureTrainingDay(date, await _plan.getAll());
    await _training.toggle(date, localId);
  }

  @override
  Future<void> savePlanItem(WorkoutPlanItem item) => _plan.save(item);
  @override
  Future<void> deletePlanItem(String id) => _plan.delete(id);

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
    final personal = await _foods.listPersonal();
    final localMatches = personal
        .where((food) => matchesFoodSearch(food.name, query))
        .toList(growable: false);
    final shared = await _foods.search(query);
    return [...localMatches, ...shared];
  }

  @override
  Future<List<FoodItem>> getPersonalFoods() => _foods.listPersonal();

  @override
  Future<DayLog> ensureDay(DateTime date, NutritionTargets targets) async {
    final profile = await getProfile();
    return _days.ensureDay(
        date: date,
        targets: targets,
        includeSchedule: profile?.deficit == null);
  }

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
