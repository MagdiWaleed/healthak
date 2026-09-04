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

  static const searchFoodOnline = AgentToolDefinition(
    name: 'search_food_online',
    description:
        'Search the real internet for a food\'s macros per 100g, only after '
        'search_foods found no catalog match. Results are grounded web '
        'sources, never catalog truth -- always tell the user these values '
        'are from the web, not the app\'s catalog, and mention the source.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'minLength': 2,
          'maxLength': 80,
          'description': 'The food name to look up, in English or Arabic.',
        },
      },
      'required': ['query'],
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
    searchFoodOnline,
  ];

  // --- Write tools (propose-only; see 02_tools.md) -------------------------
  //
  // Every one of these returns a pending proposal card for the user to
  // confirm or cancel. None of them write on their own. `slot`, when
  // present, defaults to whatever meal-time it currently is if omitted.
  // These all operate on *today* only -- the agent cannot edit past days
  // (deviation from the plan's `dateKey` argument, recorded in PROGRESS.md).

  static const _slotEnum = ['breakfast', 'lunch', 'dinner', 'snack'];

  static const proposeLogFood = AgentToolDefinition(
    name: 'propose_log_food',
    description:
        'Propose logging a catalog food at a given weight, today. food_id must be a real id from search_foods or get_meals -- never invent one.',
    parameters: {
      'type': 'object',
      'properties': {
        'food_id': {'type': 'string'},
        'grams': {'type': 'number', 'minimum': 1, 'maximum': 2000},
        'slot': {'type': 'string', 'enum': _slotEnum},
      },
      'required': ['food_id', 'grams'],
      'additionalProperties': false,
    },
  );

  static const proposeLogMeal = AgentToolDefinition(
    name: 'propose_log_meal',
    description:
        'Propose logging a full saved meal from the user\'s library as a one-shot entry, today. meal_id must come from get_meals.',
    parameters: {
      'type': 'object',
      'properties': {
        'meal_id': {'type': 'string'},
        'slot': {'type': 'string', 'enum': _slotEnum},
        'scale': {
          'type': 'number',
          'minimum': 0.1,
          'maximum': 10,
          'description': 'Portion multiplier, e.g. 0.5 for half.',
        },
      },
      'required': ['meal_id'],
      'additionalProperties': false,
    },
  );

  static const proposeSwapMeal = AgentToolDefinition(
    name: 'propose_swap_meal',
    description:
        'Propose replacing one of today\'s already-logged entries with a different saved meal. entry_id comes from get_today; new_meal_id from get_meals.',
    parameters: {
      'type': 'object',
      'properties': {
        'entry_id': {'type': 'string'},
        'new_meal_id': {'type': 'string'},
      },
      'required': ['entry_id', 'new_meal_id'],
      'additionalProperties': false,
    },
  );

  static const proposeUpdateGrams = AgentToolDefinition(
    name: 'propose_update_grams',
    description:
        'Propose changing the total weight of one of today\'s already-logged entries. entry_id comes from get_today. Every item in the entry scales proportionally.',
    parameters: {
      'type': 'object',
      'properties': {
        'entry_id': {'type': 'string'},
        'new_grams': {'type': 'number', 'minimum': 1, 'maximum': 2000},
      },
      'required': ['entry_id', 'new_grams'],
      'additionalProperties': false,
    },
  );

  static const proposeRemoveEntry = AgentToolDefinition(
    name: 'propose_remove_entry',
    description:
        'Propose removing one of today\'s already-logged entries entirely. entry_id comes from get_today.',
    parameters: {
      'type': 'object',
      'properties': {
        'entry_id': {'type': 'string'},
      },
      'required': ['entry_id'],
      'additionalProperties': false,
    },
  );

  static const proposeCreateMeal = AgentToolDefinition(
    name: 'propose_create_meal',
    description:
        'Propose saving a new meal to the user\'s library from real catalog foods. Every food_id must come from search_foods -- never invent one. Does not log it to today by itself.',
    parameters: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'minLength': 1, 'maxLength': 60},
        'entries': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 30,
          'items': {
            'type': 'object',
            'properties': {
              'food_id': {'type': 'string'},
              'grams': {'type': 'number', 'minimum': 1, 'maximum': 2000},
            },
            'required': ['food_id', 'grams'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['name', 'entries'],
      'additionalProperties': false,
    },
  );

  static const proposeLogCustomComponent = AgentToolDefinition(
    name: 'propose_log_custom_component',
    description:
        'Propose logging something with no catalog match, today. Only use after search_foods found nothing. Macros are per-100g estimates the model provides; the resulting component is saved to the user\'s personal catalog marked as estimated ("تقديري"), never the shared catalog.',
    parameters: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'minLength': 1, 'maxLength': 60},
        'protein_per_100': {'type': 'number', 'minimum': 0, 'maximum': 100},
        'carbs_per_100': {'type': 'number', 'minimum': 0, 'maximum': 100},
        'fat_per_100': {'type': 'number', 'minimum': 0, 'maximum': 100},
        'grams': {'type': 'number', 'minimum': 1, 'maximum': 2000},
        'slot': {'type': 'string', 'enum': _slotEnum},
      },
      'required': [
        'name',
        'protein_per_100',
        'carbs_per_100',
        'fat_per_100',
        'grams',
      ],
      'additionalProperties': false,
    },
  );

  static const proposeOnly = [
    proposeLogFood,
    proposeLogMeal,
    proposeSwapMeal,
    proposeUpdateGrams,
    proposeRemoveEntry,
    proposeCreateMeal,
    proposeLogCustomComponent,
  ];

  static final Set<String> proposeNames =
      proposeOnly.map((tool) => tool.name).toSet();

  static const all = [...readOnly, ...proposeOnly];
}
