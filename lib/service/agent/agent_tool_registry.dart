import '../../domain/day/day_log.dart';
import '../../domain/meal/meal_entry.dart';
import '../../domain/meal/meal_math.dart';
import '../../domain/nutrition/macros.dart';
import 'agent_data_source.dart';
import 'agent_models.dart';
import 'agent_tools.dart';

class AgentToolResult {
  final String toolName;
  final Map<String, dynamic> data;
  final bool isError;

  const AgentToolResult({
    required this.toolName,
    required this.data,
    this.isError = false,
  });
}

class AgentToolRegistry {
  final AgentDataSource _data;
  final DateTime Function() _now;

  AgentToolRegistry({
    required AgentDataSource data,
    DateTime Function()? now,
  })  : _data = data,
        _now = now ?? DateTime.now;

  List<AgentToolDefinition> get definitions => AgentTools.readOnly;

  Future<AgentToolResult> run(AgentToolCall call) async {
    try {
      final data = switch (call.name) {
        'get_today' => await _getToday(),
        'get_history_range' => await _getHistory(call.arguments),
        'get_profile' => await _getProfile(),
        'get_meals' => await _getMeals(),
        'search_foods' => await _searchFoods(call.arguments),
        'get_remaining_targets' => await _getRemainingTargets(),
        _ => throw const FormatException('unknown_tool'),
      };
      return AgentToolResult(toolName: call.name, data: data);
    } on FormatException catch (error) {
      return AgentToolResult(
        toolName: call.name,
        isError: true,
        data: {
          'error': error.message,
          'message_ar': _validationMessage(error.message),
        },
      );
    } catch (_) {
      return AgentToolResult(
        toolName: call.name,
        isError: true,
        data: const {
          'error': 'data_unavailable',
          'message_ar': 'تعذّر الوصول إلى بياناتك الآن. حاول مرة أخرى.',
        },
      );
    }
  }

  Future<Map<String, dynamic>> _getToday() async {
    final day = await _data.getDay(_now());
    if (day == null) return const {'status': 'empty', 'entries': []};
    return {
      'date': day.dateKey,
      'entries': [
        for (final entry in day.entries)
          {
            'entry_id': entry.entryId,
            'name': entry.name,
            'slot': entry.slot.name,
            'slot_ar': entry.slot.labelAr,
            'eaten': entry.eaten,
            'items': [
              for (final item in entry.items)
                {
                  'food_id': item.foodId,
                  'name': item.name,
                  'grams': item.grams,
                  'macros': _macros(item.macros),
                },
            ],
            'totals': _macros(entry.totals),
          },
      ],
      'consumed': _macros(day.consumedTotals),
      'planned': _macros(day.plannedTotals),
      'targets': _targets(day),
    };
  }

  Future<Map<String, dynamic>> _getHistory(
      Map<String, dynamic> arguments) async {
    final rawDays = arguments['days'];
    if (rawDays is! num) throw const FormatException('days_required');
    final days = rawDays.toInt();
    if (days < 1 || days > 7) throw const FormatException('days_out_of_range');
    final end = DateTime(_now().year, _now().month, _now().day);
    final start = end.subtract(Duration(days: days - 1));
    final logs = await _data.getHistory(start, end);
    return {
      'requested_days': days,
      'days': [
        for (final day in logs)
          {
            'date': day.dateKey,
            'consumed': _macros(day.consumedTotals),
            'target_kcal': day.targets.kcal,
            'progress': day.progress,
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _getProfile() async {
    final profile = await _data.getProfile();
    if (profile == null) return const {'status': 'missing'};
    return {
      'display_name': profile.displayName,
      'sex': profile.sex.name,
      'age': profile.ageAt(_now()),
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'activity': profile.activityLevel.name,
      'goal': profile.goal.name,
      'weekly_rate_kg': profile.weeklyRateKg,
      'targets': {
        'kcal': profile.targets.kcal,
        ..._macros(profile.targets.macros),
      },
    };
  }

  Future<Map<String, dynamic>> _getMeals() async {
    final meals = await _data.getMeals();
    final resolver = MealResolver(meals);
    return {
      'meals': [
        for (final meal in meals)
          {
            'meal_id': meal.id,
            'name': meal.name,
            // The stored cache is intentionally not treated as truth here.
            'totals': _macros(macrosOfMeal(meal, resolver)),
            'components': [
              for (final entry in meal.entries)
                switch (entry) {
                  FoodEntry(:final foodId, :final name, :final grams) => {
                      'kind': 'food',
                      'food_id': foodId,
                      'name': name,
                      'grams': grams,
                    },
                  MealRefEntry(:final mealId, :final name, :final scale) => {
                      'kind': 'meal',
                      'meal_id': mealId,
                      'name': name,
                      'scale': scale,
                    },
                },
            ],
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _searchFoods(
      Map<String, dynamic> arguments) async {
    final query = arguments['query'];
    if (query is! String || query.trim().runes.length < 2) {
      throw const FormatException('query_too_short');
    }
    if (query.runes.length > 80) throw const FormatException('query_too_long');
    final foods = await _data.searchFoods(query.trim());
    return {
      'query': query.trim(),
      'foods': [
        for (final food in foods.take(12))
          {
            'food_id': food.id,
            'name': food.name,
            'category': food.category,
            'per_100g': _macros(food.per100),
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _getRemainingTargets() async {
    final day = await _data.getDay(_now());
    if (day == null) return const {'status': 'empty'};
    final remaining = day.targets.macros - day.consumedTotals;
    return {
      'date': day.dateKey,
      'remaining': {
        'kcal': (day.targets.kcal - day.consumedKcal).clamp(0, double.infinity),
        'protein_g': remaining.protein.clamp(0, double.infinity),
        'carbs_g': remaining.carbs.clamp(0, double.infinity),
        'fat_g': remaining.fat.clamp(0, double.infinity),
      },
      'over_target': day.consumedKcal > day.targets.kcal,
    };
  }

  static Map<String, dynamic> _targets(DayLog day) => {
        'kcal': day.targets.kcal,
        ..._macros(day.targets.macros),
      };

  static Map<String, dynamic> _macros(Macros macros) => {
        'protein_g': macros.protein,
        'carbs_g': macros.carbs,
        'fat_g': macros.fat,
        'kcal': macros.kcal,
      };

  static String _validationMessage(String code) => switch (code) {
        'days_required' => 'حدّد عدد الأيام المطلوبة.',
        'days_out_of_range' => 'يمكن قراءة آخر 7 أيام كحد أقصى.',
        'query_too_short' => 'اكتب حرفين على الأقل للبحث.',
        'query_too_long' => 'عبارة البحث طويلة جدًا.',
        'unknown_tool' => 'هذه الأداة غير متاحة.',
        _ => 'تعذّر تنفيذ الطلب.',
      };
}
