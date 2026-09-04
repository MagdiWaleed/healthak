class AgentToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const AgentToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

abstract final class AgentTools {
  static const getToday = AgentToolDefinition(
    name: 'get_today',
    description:
        'Read the user\'s current day log, including food entries, eaten state, totals, and targets.',
    parameters: {
      'type': 'object',
      'properties': <String, dynamic>{},
      'additionalProperties': false,
    },
  );

  static const getHistoryRange = AgentToolDefinition(
    name: 'get_history_range',
    description:
        'Read recent consumed and target nutrition summaries. Free users can request at most 7 days.',
    parameters: {
      'type': 'object',
      'properties': {
        'days': {
          'type': 'integer',
          'minimum': 1,
          'maximum': 7,
          'description': 'Number of days ending today.',
        },
      },
      'required': ['days'],
      'additionalProperties': false,
    },
  );

  static const getProfile = AgentToolDefinition(
    name: 'get_profile',
    description:
        'Read body statistics, activity, goal, and the calculated daily nutrition targets. Never returns email.',
    parameters: {
      'type': 'object',
      'properties': <String, dynamic>{},
      'additionalProperties': false,
    },
  );

  static const getMeals = AgentToolDefinition(
    name: 'get_meals',
    description:
        'Read the user\'s saved meal library with grounded totals and component names.',
    parameters: {
      'type': 'object',
      'properties': <String, dynamic>{},
      'additionalProperties': false,
    },
  );

  static const searchFoods = AgentToolDefinition(
    name: 'search_foods',
    description:
        'Search the real shared and personal food catalogs. Use this before making claims about a food\'s macros.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'minLength': 2,
          'maxLength': 80,
          'description': 'Arabic or English food name.',
        },
      },
      'required': ['query'],
      'additionalProperties': false,
    },
  );

  static const getRemainingTargets = AgentToolDefinition(
    name: 'get_remaining_targets',
    description:
        'Calculate kcal, protein, carbs, and fat remaining today from the real day log.',
    parameters: {
      'type': 'object',
      'properties': <String, dynamic>{},
      'additionalProperties': false,
    },
  );

  static const readOnly = [
    getToday,
    getHistoryRange,
    getProfile,
    getMeals,
    searchFoods,
    getRemainingTargets,
  ];
}
