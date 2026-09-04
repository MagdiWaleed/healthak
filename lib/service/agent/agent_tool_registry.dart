import 'package:uuid/uuid.dart';

import '../../domain/day/day_log.dart';
import '../../domain/food/food_item.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/meal/meal_entry.dart';
import '../../domain/meal/meal_math.dart';
import '../../domain/nutrition/energy.dart';
import '../../domain/nutrition/macros.dart';
import 'agent_data_source.dart';
import 'agent_models.dart';
import 'agent_proposal.dart';
import 'agent_tools.dart';
import 'web_food_search_client.dart';

class AgentToolResult {
  final String toolName;
  final Map<String, dynamic> data;
  final bool isError;

  /// Set only for a write tool call that built a valid pending proposal.
  /// [ChatOrchestrator] parks this in the conversation as a confirmation
  /// card instead of treating [data] as a finished answer.
  final Proposal? proposal;

  const AgentToolResult({
    required this.toolName,
    required this.data,
    this.isError = false,
    this.proposal,
  });
}

class AgentToolRegistry {
  final AgentDataSource _data;
  final DateTime Function() _now;
  final Uuid _uuid;
  final WebFoodSearchClient? _webSearch;

  AgentToolRegistry({
    required AgentDataSource data,
    DateTime Function()? now,
    Uuid uuid = const Uuid(),
    WebFoodSearchClient? webSearch,
  })  : _data = data,
        _now = now ?? DateTime.now,
        _uuid = uuid,
        _webSearch = webSearch;

  List<AgentToolDefinition> get definitions => AgentTools.all;

  /// A compact, precalled listing of the user's own personal components and
  /// saved meals with their real ids -- sent as extra system context so the
  /// model has these ids upfront instead of guessing one or having to
  /// search for something it already owns. The shared catalog is far too
  /// large for this and still goes through search_foods as before.
  Future<String> buildKnownCatalogContext() async {
    final results = await Future.wait([_data.getPersonalFoods(), _data.getMeals()]);
    final personalFoods = results[0] as List<FoodItem>;
    final meals = results[1] as List<MealDefinition>;
    if (personalFoods.isEmpty && meals.isEmpty) return '';

    final buffer = StringBuffer(
      'بيانات معروفة مسبقًا عن حساب هذا المستخدم -- استخدم هذه المعرّفات '
      'مباشرة في أدوات propose_*، لا تخترع معرّفًا غيرها ولا داعي للبحث '
      'عنها عبر search_foods أو get_meals مجددًا:\n',
    );
    if (personalFoods.isNotEmpty) {
      buffer.writeln('مكوّناته الشخصية:');
      for (final food in personalFoods.take(60)) {
        buffer.writeln('- ${food.name} (food_id: ${food.id})');
      }
    }
    if (meals.isNotEmpty) {
      buffer.writeln('وجباته المحفوظة:');
      for (final meal in meals.take(60)) {
        buffer.writeln('- ${meal.name} (meal_id: ${meal.id})');
      }
    }
    return buffer.toString().trim();
  }

  Future<AgentToolResult> run(AgentToolCall call) async {
    try {
      if (AgentTools.proposeNames.contains(call.name)) {
        final proposal = await _buildProposal(call);
        return AgentToolResult(
          toolName: call.name,
          data: proposal.modelSummary,
          proposal: proposal,
        );
      }
      final data = switch (call.name) {
        'get_today' => await _getToday(),
        'get_history_range' => await _getHistory(call.arguments),
        'get_profile' => await _getProfile(),
        'get_meals' => await _getMeals(),
        'search_foods' => await _searchFoods(call.arguments),
        'get_remaining_targets' => await _getRemainingTargets(),
        'search_food_online' => await _searchFoodOnline(call.arguments),
        _ => throw const FormatException('unknown_tool'),
      };
      return AgentToolResult(toolName: call.name, data: data);
    } on AgentException catch (error) {
      // Only reachable from search_food_online's own client -- surfaces its
      // specific offline/quota/server message instead of the generic
      // fallback below.
      return AgentToolResult(
        toolName: call.name,
        isError: true,
        data: {'error': error.kind.name, 'message_ar': error.message},
      );
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

  // ---------------------------------------------------------------------
  // Confirm / undo
  // ---------------------------------------------------------------------

  /// Executes a confirmed [proposal] via the real repositories and returns a
  /// receipt carrying whatever would undo it.
  ///
  /// Throws [AgentProposalStaleException] if the entry the proposal targets
  /// has changed (or vanished) since the proposal was built.
  Future<AgentReceipt> confirm(Proposal proposal) async {
    switch (proposal.kind) {
      case ProposalKind.logFood:
        {
          final a = proposal.execArgs as _LogFoodArgs;
          final day = await _ensureToday();
          final entry = DayEntry(
            entryId: _uuid.v4(),
            origin: DayEntryOrigin.quickAdd,
            name: a.food.name,
            slot: a.slot,
            order: day.entries.length,
            items: [
              FrozenItem(
                foodId: a.food.id,
                name: a.food.name,
                per100: a.food.per100,
                grams: a.grams,
              ),
            ],
          );
          await _data.upsertDayEntry(day.dateKey, entry);
          return _receipt(
            proposal,
            'سجّلت ${a.food.name} (${_fmt(a.grams)} جم) في ${a.slot.labelAr}.',
            [_removeEntryProposal(entry, day.dateKey)],
          );
        }

      case ProposalKind.logMeal:
        {
          final a = proposal.execArgs as _LogMealArgs;
          final day = await _ensureToday();
          final entry = DayEntry(
            entryId: _uuid.v4(),
            origin: DayEntryOrigin.oneShot,
            sourceMealId: a.mealId,
            name: a.name,
            slot: a.slot,
            order: day.entries.length,
            items: a.items,
          );
          await _data.upsertDayEntry(day.dateKey, entry);
          return _receipt(
            proposal,
            'سجّلت ${a.name} في ${a.slot.labelAr}.',
            [_removeEntryProposal(entry, day.dateKey)],
          );
        }

      case ProposalKind.swapMeal:
        {
          final a = proposal.execArgs as _SwapMealArgs;
          await _assertFresh(a.dateKey, a.oldEntry);
          final newEntry = DayEntry(
            entryId: _uuid.v4(),
            origin: DayEntryOrigin.oneShot,
            sourceMealId: a.newMealId,
            name: a.newName,
            slot: a.oldEntry.slot,
            order: a.oldEntry.order,
            items: a.newItems,
          );
          await _data.removeDayEntry(a.dateKey, a.oldEntry.entryId);
          await _data.upsertDayEntry(a.dateKey, newEntry);
          return _receipt(
            proposal,
            'استبدلت ${a.oldEntry.name} بـ ${a.newName}.',
            [
              _removeEntryProposal(newEntry, a.dateKey),
              _restoreEntryProposal(a.oldEntry, a.dateKey),
            ],
          );
        }

      case ProposalKind.updateGrams:
        {
          final a = proposal.execArgs as _UpdateGramsArgs;
          await _assertFresh(a.dateKey, a.oldEntry);
          await _data.upsertDayEntry(
            a.dateKey,
            a.oldEntry.copyWith(items: a.newItems),
          );
          return _receipt(
            proposal,
            'غيّرت ${a.oldEntry.name} من ${_fmt(a.oldGrams)} إلى ${_fmt(a.newGrams)} جم.',
            [_restoreEntryProposal(a.oldEntry, a.dateKey)],
          );
        }

      case ProposalKind.removeEntry:
        {
          final a = proposal.execArgs as _EntrySnapshotArgs;
          await _assertFresh(a.dateKey, a.entry);
          await _data.removeDayEntry(a.dateKey, a.entry.entryId);
          return _receipt(
            proposal,
            'حذفت ${a.entry.name} من يومك.',
            [_restoreEntryProposal(a.entry, a.dateKey)],
          );
        }

      case ProposalKind.restoreEntry:
        {
          final a = proposal.execArgs as _EntrySnapshotArgs;
          await _data.upsertDayEntry(a.dateKey, a.entry);
          return _receipt(
            proposal,
            'استعدت ${a.entry.name}.',
            [_removeEntryProposal(a.entry, a.dateKey)],
          );
        }

      case ProposalKind.createMeal:
        {
          final a = proposal.execArgs as _CreateMealArgs;
          final saved = await _data.saveMeal(a.draft);
          return _receipt(
            proposal,
            'حفظت ${saved.name} في مكتبتك.',
            [_deleteMealProposal(saved.id)],
          );
        }

      case ProposalKind.deleteMeal:
        {
          final a = proposal.execArgs as _DeleteMealArgs;
          await _data.deleteMeal(a.mealId);
          return _receipt(proposal, 'حذفت الوجبة من مكتبتك.', const []);
        }

      case ProposalKind.logCustomComponent:
        {
          final a = proposal.execArgs as _LogCustomComponentArgs;
          final created = await _data.createPersonalFood(FoodItem(
            id: '',
            name: a.name,
            per100: a.per100,
            note: 'أضافه المساعد (تقديري)',
          ));
          final day = await _ensureToday();
          final entry = DayEntry(
            entryId: _uuid.v4(),
            origin: DayEntryOrigin.quickAdd,
            name: a.name,
            slot: a.slot,
            order: day.entries.length,
            items: [
              FrozenItem(
                foodId: created.id,
                name: a.name,
                per100: a.per100,
                grams: a.grams,
              ),
            ],
          );
          await _data.upsertDayEntry(day.dateKey, entry);
          return _receipt(
            proposal,
            'أضفت ${a.name} (تقديري) كمكوّن شخصي وسجّلته (${_fmt(a.grams)} جم) في ${a.slot.labelAr}.',
            [_removeEntryProposal(entry, day.dateKey)],
          );
        }
    }
  }

  /// Undoing a receipt is just confirming its inverse chain, in order.
  /// Returns every step's own receipt (swap's inverse is two real writes,
  /// everything else is one) -- Phase 5C's audit log records each one as its
  /// own entry, since "an undo is itself a logged action" per the plan.
  Future<List<AgentReceipt>> undo(AgentReceipt receipt) async {
    if (!receipt.isUndoable) {
      throw StateError('Receipt ${receipt.id} has nothing to undo');
    }
    final steps = <AgentReceipt>[];
    for (final step in receipt.inverse) {
      steps.add(await confirm(step));
    }
    return steps;
  }

  // ---------------------------------------------------------------------
  // Audit-log (de)serialization -- Phase 5C, `lib/page/history_ai/`.
  //
  // Only ever called on a proposal's *inverse* chain, never the forward
  // action a user actually asked for -- so only the two shapes `confirm`
  // ever produces as an inverse need to round-trip through JSON: an entry
  // snapshot (`removeEntry`/`restoreEntry`) and a bare meal id
  // (`deleteMeal`). This is what lets a "تراجع" tap in the persisted audit
  // screen replay a write from a *previous* app session, where no live
  // `Proposal` object exists in memory -- unlike the inline chat receipt
  // chip, which just holds on to the one it already built.
  // ---------------------------------------------------------------------

  /// Returns `null` for a kind that never appears as an inverse (every
  /// forward-only kind) -- callers skip those when building a log entry's
  /// inverse chain.
  Map<String, dynamic>? serializeProposalForLog(Proposal proposal) {
    switch (proposal.kind) {
      case ProposalKind.removeEntry:
      case ProposalKind.restoreEntry:
        final a = proposal.execArgs as _EntrySnapshotArgs;
        return {
          'kind': proposal.kind.name,
          'dateKey': a.dateKey,
          'entry': _entryToJson(a.entry),
        };
      case ProposalKind.deleteMeal:
        final a = proposal.execArgs as _DeleteMealArgs;
        return {'kind': proposal.kind.name, 'mealId': a.mealId};
      case ProposalKind.logFood:
      case ProposalKind.logMeal:
      case ProposalKind.swapMeal:
      case ProposalKind.updateGrams:
      case ProposalKind.createMeal:
      case ProposalKind.logCustomComponent:
        return null;
    }
  }

  /// The inverse of [serializeProposalForLog]. Returns `null` on any
  /// malformed or unrecognized row rather than throwing -- a corrupt log
  /// row should just render non-undoable, never crash the history screen.
  Proposal? deserializeProposalForLog(Map<String, dynamic> json) {
    try {
      final kind = ProposalKind.values
          .firstWhere((k) => k.name == json['kind'], orElse: () => throw 0);
      switch (kind) {
        case ProposalKind.removeEntry:
        case ProposalKind.restoreEntry:
          final entry = _entryFromJson(
              (json['entry'] as Map).cast<String, dynamic>());
          final dateKey = json['dateKey'] as String;
          return kind == ProposalKind.removeEntry
              ? _removeEntryProposal(entry, dateKey)
              : _restoreEntryProposal(entry, dateKey);
        case ProposalKind.deleteMeal:
          return _deleteMealProposal(json['mealId'] as String);
        default:
          return null;
      }
    } on Object {
      return null;
    }
  }

  static Map<String, dynamic> _entryToJson(DayEntry entry) => {
        'entryId': entry.entryId,
        'origin': entry.origin.name,
        'scheduleItemId': entry.scheduleItemId,
        'sourceMealId': entry.sourceMealId,
        'name': entry.name,
        'slot': entry.slot.name,
        'order': entry.order,
        'eaten': entry.eaten,
        'eatenAt': entry.eatenAt?.toIso8601String(),
        'items': entry.items.map((item) => item.toJson()).toList(),
      };

  static DayEntry _entryFromJson(Map<String, dynamic> json) => DayEntry(
        entryId: json['entryId'] as String,
        origin: DayEntryOrigin.values.firstWhere(
          (o) => o.name == json['origin'],
          orElse: () => DayEntryOrigin.oneShot,
        ),
        scheduleItemId: json['scheduleItemId'] as String?,
        sourceMealId: json['sourceMealId'] as String?,
        name: json['name'] as String? ?? '',
        slot: MealSlot.values.firstWhere(
          (s) => s.name == json['slot'],
          orElse: () => MealSlot.snack,
        ),
        order: (json['order'] as num?)?.toInt() ?? 0,
        eaten: json['eaten'] as bool? ?? false,
        eatenAt: json['eatenAt'] != null
            ? DateTime.tryParse(json['eatenAt'] as String)
            : null,
        items: (json['items'] as List)
            .map((item) => FrozenItem.fromJson((item as Map).cast<String, dynamic>()))
            .toList(),
      );

  AgentReceipt _receipt(
    Proposal proposal,
    String summaryAr,
    List<Proposal> inverse,
  ) =>
      AgentReceipt(
        id: _uuid.v4(),
        kind: proposal.kind,
        summaryAr: summaryAr,
        inverse: inverse,
        executedAt: _now(),
      );

  /// Re-fetches the day and refuses to proceed if [expected] no longer
  /// matches what's actually there -- someone edited or deleted it since the
  /// proposal was built.
  Future<void> _assertFresh(String dateKey, DayEntry expected) async {
    final day = await _data.getDayByKey(dateKey);
    final current =
        day?.entries.where((e) => e.entryId == expected.entryId).firstOrNull;
    if (current == null ||
        current.items.length != expected.items.length ||
        current.totals.kcal != expected.totals.kcal ||
        current.eaten != expected.eaten) {
      throw const AgentProposalStaleException();
    }
  }

  Future<DayLog> _ensureToday() async {
    final profile = await _data.getProfile();
    return _data.ensureDay(_now(), profile?.targets ?? NutritionTargets.empty);
  }

  Proposal _removeEntryProposal(DayEntry entry, String dateKey) => Proposal(
        id: _uuid.v4(),
        toolCallId: '',
        kind: ProposalKind.removeEntry,
        titleAr: 'إزالة ${entry.name}',
        card: {'name': entry.name},
        modelSummary: const {},
        execArgs: _EntrySnapshotArgs(entry: entry, dateKey: dateKey),
      );

  Proposal _restoreEntryProposal(DayEntry entry, String dateKey) => Proposal(
        id: _uuid.v4(),
        toolCallId: '',
        kind: ProposalKind.restoreEntry,
        titleAr: 'استعادة ${entry.name}',
        card: {'name': entry.name},
        modelSummary: const {},
        execArgs: _EntrySnapshotArgs(entry: entry, dateKey: dateKey),
      );

  Proposal _deleteMealProposal(String mealId) => Proposal(
        id: _uuid.v4(),
        toolCallId: '',
        kind: ProposalKind.deleteMeal,
        titleAr: 'حذف الوجبة',
        card: const {},
        modelSummary: const {},
        execArgs: _DeleteMealArgs(mealId: mealId),
      );

  // ---------------------------------------------------------------------
  // Proposal builders (one per propose_* tool)
  // ---------------------------------------------------------------------

  Future<Proposal> _buildProposal(AgentToolCall call) => switch (call.name) {
        'propose_log_food' => _proposeLogFood(call),
        'propose_log_meal' => _proposeLogMeal(call),
        'propose_swap_meal' => _proposeSwapMeal(call),
        'propose_update_grams' => _proposeUpdateGrams(call),
        'propose_remove_entry' => _proposeRemoveEntry(call),
        'propose_create_meal' => _proposeCreateMeal(call),
        'propose_log_custom_component' => _proposeLogCustomComponent(call),
        _ => throw const FormatException('unknown_tool'),
      };

  Future<Proposal> _proposeLogFood(AgentToolCall call) async {
    final args = call.arguments;
    final foodId = args['food_id'];
    if (foodId is! String || foodId.isEmpty) {
      throw const FormatException('food_id_required');
    }
    final grams = _requireGrams(args['grams']);
    final slot = _parseSlot(args['slot']) ?? _inferSlot();
    final food = await _data.getFoodById(foodId);
    if (food == null) throw const FormatException('food_not_found');

    final macros = food.per100.forGrams(grams);
    return Proposal(
      id: _uuid.v4(),
      toolCallId: call.id,
      kind: ProposalKind.logFood,
      titleAr: 'هسجّل ${food.name} (${_fmt(grams)} جم) في ${slot.labelAr}',
      card: {
        'name': food.name,
        'grams': grams,
        'slot_ar': slot.labelAr,
        'macros': _macrosJson(macros),
      },
      modelSummary: {
        'status': 'awaiting_confirmation',
        'summary_ar': 'اقتراح جاهز: تسجيل ${food.name}. بانتظار تأكيد المستخدم.',
      },
      execArgs: _LogFoodArgs(food: food, grams: grams, slot: slot),
    );
  }

  Future<Proposal> _proposeLogMeal(AgentToolCall call) async {
    final args = call.arguments;
    final mealId = args['meal_id'];
    if (mealId is! String || mealId.isEmpty) {
      throw const FormatException('meal_id_required');
    }
    final scale = _clamp((args['scale'] as num?)?.toDouble() ?? 1.0, 0.1, 10);
    final slot = _parseSlot(args['slot']) ?? _inferSlot();
    final meal = await _data.getMealById(mealId);
    if (meal == null) throw const FormatException('meal_not_found');

    final allMeals = await _data.getMeals();
    final resolver = MealResolver(
      allMeals.any((m) => m.id == meal.id) ? allMeals : [...allMeals, meal],
    );
    final items = flattenMeal(meal, resolver, scale: scale)
        .map(FrozenItem.fromFlat)
        .toList(growable: false);
    final totals = items.fold(Macros.zero, (Macros a, i) => a + i.macros);

    return Proposal(
      id: _uuid.v4(),
      toolCallId: call.id,
      kind: ProposalKind.logMeal,
      titleAr: 'هسجّل ${meal.name} في ${slot.labelAr}',
      card: {
        'name': meal.name,
        'slot_ar': slot.labelAr,
        'scale': scale,
        'macros': _macrosJson(totals),
      },
      modelSummary: {
        'status': 'awaiting_confirmation',
        'summary_ar': 'اقتراح جاهز: تسجيل ${meal.name}. بانتظار تأكيد المستخدم.',
      },
      execArgs: _LogMealArgs(
        mealId: meal.id,
        name: meal.name,
        items: items,
        slot: slot,
      ),
    );
  }

  Future<Proposal> _proposeSwapMeal(AgentToolCall call) async {
    final args = call.arguments;
    final entryId = args['entry_id'];
    final newMealId = args['new_meal_id'];
    if (entryId is! String || entryId.isEmpty) {
      throw const FormatException('entry_id_required');
    }
    if (newMealId is! String || newMealId.isEmpty) {
      throw const FormatException('new_meal_id_required');
    }
    final day = await _data.getDay(_now());
    final oldEntry =
        day?.entries.where((e) => e.entryId == entryId).firstOrNull;
    if (day == null || oldEntry == null) {
      throw const FormatException('entry_not_found');
    }
    final newMeal = await _data.getMealById(newMealId);
    if (newMeal == null) throw const FormatException('meal_not_found');

    final allMeals = await _data.getMeals();
    final resolver = MealResolver(
      allMeals.any((m) => m.id == newMeal.id)
          ? allMeals
          : [...allMeals, newMeal],
    );
    final newItems = flattenMeal(newMeal, resolver)
        .map(FrozenItem.fromFlat)
        .toList(growable: false);
    final newTotals = newItems.fold(Macros.zero, (Macros a, i) => a + i.macros);
    final oldTotals = oldEntry.totals;
    final delta = newTotals - oldTotals;

    return Proposal(
      id: _uuid.v4(),
      toolCallId: call.id,
      kind: ProposalKind.swapMeal,
      titleAr: 'هستبدل ${oldEntry.name} بـ ${newMeal.name}',
      card: {
        'old_name': oldEntry.name,
        'new_name': newMeal.name,
        'old_macros': _macrosJson(oldTotals),
        'new_macros': _macrosJson(newTotals),
        'delta': _macrosJson(delta),
      },
      modelSummary: {
        'status': 'awaiting_confirmation',
        'summary_ar':
            'اقتراح جاهز: استبدال ${oldEntry.name} بـ ${newMeal.name}. بانتظار تأكيد المستخدم.',
      },
      execArgs: _SwapMealArgs(
        oldEntry: oldEntry,
        newMealId: newMeal.id,
        newName: newMeal.name,
        newItems: newItems,
        dateKey: day.dateKey,
      ),
    );
  }

  Future<Proposal> _proposeUpdateGrams(AgentToolCall call) async {
    final args = call.arguments;
    final entryId = args['entry_id'];
    if (entryId is! String || entryId.isEmpty) {
      throw const FormatException('entry_id_required');
    }
    final newGrams = _requireGrams(args['new_grams']);
    final day = await _data.getDay(_now());
    final entry = day?.entries.where((e) => e.entryId == entryId).firstOrNull;
    if (day == null || entry == null) {
      throw const FormatException('entry_not_found');
    }
    final oldGrams = entry.items.fold(0.0, (double a, i) => a + i.grams);
    if (oldGrams <= 0) throw const FormatException('entry_not_weighable');
    final factor = newGrams / oldGrams;
    final newItems = entry.items
        .map((item) => item.withGrams(item.grams * factor))
        .toList(growable: false);

    return Proposal(
      id: _uuid.v4(),
      toolCallId: call.id,
      kind: ProposalKind.updateGrams,
      titleAr: 'هغيّر ${entry.name} من ${_fmt(oldGrams)} لـ ${_fmt(newGrams)} جم',
      card: {
        'name': entry.name,
        'old_grams': oldGrams,
        'new_grams': newGrams,
      },
      modelSummary: {
        'status': 'awaiting_confirmation',
        'summary_ar':
            'اقتراح جاهز: تغيير وزن ${entry.name}. بانتظار تأكيد المستخدم.',
      },
      execArgs: _UpdateGramsArgs(
        oldEntry: entry,
        oldGrams: oldGrams,
        newGrams: newGrams,
        newItems: newItems,
        dateKey: day.dateKey,
      ),
    );
  }

  Future<Proposal> _proposeRemoveEntry(AgentToolCall call) async {
    final args = call.arguments;
    final entryId = args['entry_id'];
    if (entryId is! String || entryId.isEmpty) {
      throw const FormatException('entry_id_required');
    }
    final day = await _data.getDay(_now());
    final entry = day?.entries.where((e) => e.entryId == entryId).firstOrNull;
    if (day == null || entry == null) {
      throw const FormatException('entry_not_found');
    }

    return Proposal(
      id: _uuid.v4(),
      toolCallId: call.id,
      kind: ProposalKind.removeEntry,
      titleAr: 'هشيل ${entry.name} من يومك',
      card: {'name': entry.name, 'kcal': entry.totals.kcal},
      modelSummary: {
        'status': 'awaiting_confirmation',
        'summary_ar': 'اقتراح جاهز: حذف ${entry.name}. بانتظار تأكيد المستخدم.',
      },
      execArgs: _EntrySnapshotArgs(entry: entry, dateKey: day.dateKey),
    );
  }

  Future<Proposal> _proposeCreateMeal(AgentToolCall call) async {
    final args = call.arguments;
    final name = args['name'];
    if (name is! String || name.trim().isEmpty || name.runes.length > 60) {
      throw const FormatException('name_invalid');
    }
    final rawEntries = args['entries'];
    if (rawEntries is! List || rawEntries.isEmpty || rawEntries.length > 30) {
      throw const FormatException('entries_invalid');
    }

    final foodEntries = <FoodEntry>[];
    for (var i = 0; i < rawEntries.length; i++) {
      final raw = rawEntries[i];
      if (raw is! Map) throw const FormatException('entries_invalid');
      final foodId = raw['food_id'];
      if (foodId is! String || foodId.isEmpty) {
        throw const FormatException('entries_invalid');
      }
      final grams = _requireGrams(raw['grams']);
      final food = await _data.getFoodById(foodId);
      if (food == null) throw const FormatException('food_not_found');
      foodEntries.add(FoodEntry(
        localId: _uuid.v4(),
        order: i,
        foodId: food.id,
        name: food.name,
        per100: food.per100,
        grams: grams,
      ));
    }

    final now = _now();
    final draft = MealDefinition(
      id: _uuid.v4(),
      ownerUid: _data.uid,
      name: name.trim(),
      entries: foodEntries,
      createdAt: now,
      updatedAt: now,
    );
    final totals = draft.entries
        .whereType<FoodEntry>()
        .fold(Macros.zero, (Macros a, e) => a + e.macros);

    return Proposal(
      id: _uuid.v4(),
      toolCallId: call.id,
      kind: ProposalKind.createMeal,
      titleAr: 'هحفظ وجبة جديدة: ${draft.name}',
      card: {
        'name': draft.name,
        'component_count': foodEntries.length,
        'macros': _macrosJson(totals),
      },
      modelSummary: {
        'status': 'awaiting_confirmation',
        'summary_ar':
            'اقتراح جاهز: حفظ وجبة "${draft.name}" في المكتبة. بانتظار تأكيد المستخدم.',
      },
      execArgs: _CreateMealArgs(draft: draft),
    );
  }

  Future<Proposal> _proposeLogCustomComponent(AgentToolCall call) async {
    final args = call.arguments;
    final name = args['name'];
    if (name is! String || name.trim().isEmpty || name.runes.length > 60) {
      throw const FormatException('name_invalid');
    }
    final protein = _requireMacroGram(args['protein_per_100']);
    final carbs = _requireMacroGram(args['carbs_per_100']);
    final fat = _requireMacroGram(args['fat_per_100']);
    final grams = _requireGrams(args['grams']);
    final slot = _parseSlot(args['slot']) ?? _inferSlot();
    final per100 = Macros(protein: protein, carbs: carbs, fat: fat);

    return Proposal(
      id: _uuid.v4(),
      toolCallId: call.id,
      kind: ProposalKind.logCustomComponent,
      titleAr: 'هضيف ${name.trim()} كمكوّن شخصي (تقديري)',
      card: {
        'name': name.trim(),
        'grams': grams,
        'slot_ar': slot.labelAr,
        'macros': _macrosJson(per100.forGrams(grams)),
        'estimated': true,
      },
      modelSummary: {
        'status': 'awaiting_confirmation',
        'summary_ar':
            'اقتراح جاهز: تسجيل ${name.trim()} كمكوّن تقديري. بانتظار تأكيد المستخدم.',
      },
      execArgs: _LogCustomComponentArgs(
        name: name.trim(),
        per100: per100,
        grams: grams,
        slot: slot,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Read tools (unchanged from Phase 5A)
  // ---------------------------------------------------------------------

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

  Future<Map<String, dynamic>> _searchFoodOnline(
      Map<String, dynamic> arguments) async {
    final query = arguments['query'];
    if (query is! String || query.trim().runes.length < 2) {
      throw const FormatException('query_too_short');
    }
    if (query.runes.length > 80) throw const FormatException('query_too_long');
    final client = _webSearch;
    if (client == null) throw const FormatException('search_unavailable');
    final result = await client.search(query.trim());
    return {
      'query': query.trim(),
      'source': 'web',
      'text': result.text,
      'sources': result.sources,
    };
  }

  // ---------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------

  MealSlot? _parseSlot(Object? raw) {
    if (raw is! String) return null;
    for (final slot in MealSlot.values) {
      if (slot.name == raw) return slot;
    }
    return null;
  }

  MealSlot _inferSlot() {
    final hour = _now().hour;
    if (hour < 11) return MealSlot.breakfast;
    if (hour < 16) return MealSlot.lunch;
    if (hour < 21) return MealSlot.dinner;
    return MealSlot.snack;
  }

  double _requireGrams(Object? raw) {
    if (raw is! num) throw const FormatException('grams_required');
    return _clamp(raw.toDouble(), 1, 2000);
  }

  double _requireMacroGram(Object? raw) {
    if (raw is! num) throw const FormatException('macros_required');
    return _clamp(raw.toDouble(), 0, 100);
  }

  static double _clamp(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);

  static String _fmt(double grams) => grams == grams.roundToDouble()
      ? grams.toInt().toString()
      : grams.toStringAsFixed(1);

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

  static Map<String, num> _macrosJson(Macros macros) => {
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
        'food_id_required' => 'حدّد المكوّن المطلوب.',
        'food_not_found' => 'لم أجد هذا المكوّن في الكتالوج.',
        'meal_id_required' => 'حدّد الوجبة المطلوبة.',
        'new_meal_id_required' => 'حدّد الوجبة الجديدة.',
        'meal_not_found' => 'لم أجد هذه الوجبة في مكتبتك.',
        'entry_id_required' => 'حدّد العنصر المطلوب من سجل اليوم.',
        'entry_not_found' => 'لم أجد هذا العنصر في سجل اليوم.',
        'entry_not_weighable' => 'لا يمكن تغيير وزن هذا العنصر.',
        'grams_required' => 'حدّد الوزن بالجرام.',
        'macros_required' => 'حدّد القيم الغذائية لكل ١٠٠ جم.',
        'name_invalid' => 'اسم غير صالح.',
        'entries_invalid' => 'قائمة المكوّنات غير صالحة.',
        'search_unavailable' => 'البحث في الإنترنت غير متاح الآن.',
        'unknown_tool' => 'هذه الأداة غير متاحة.',
        _ => 'تعذّر تنفيذ الطلب.',
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

// ---------------------------------------------------------------------
// Resolved proposal payloads. Private -- only [AgentToolRegistry] builds or
// reads these, so no un-validated data can leak into a `confirm` call.
// ---------------------------------------------------------------------

class _LogFoodArgs {
  final FoodItem food;
  final double grams;
  final MealSlot slot;
  const _LogFoodArgs({required this.food, required this.grams, required this.slot});
}

class _LogMealArgs {
  final String mealId;
  final String name;
  final List<FrozenItem> items;
  final MealSlot slot;
  const _LogMealArgs({
    required this.mealId,
    required this.name,
    required this.items,
    required this.slot,
  });
}

class _SwapMealArgs {
  final DayEntry oldEntry;
  final String newMealId;
  final String newName;
  final List<FrozenItem> newItems;
  final String dateKey;
  const _SwapMealArgs({
    required this.oldEntry,
    required this.newMealId,
    required this.newName,
    required this.newItems,
    required this.dateKey,
  });
}

class _UpdateGramsArgs {
  final DayEntry oldEntry;
  final double oldGrams;
  final double newGrams;
  final List<FrozenItem> newItems;
  final String dateKey;
  const _UpdateGramsArgs({
    required this.oldEntry,
    required this.oldGrams,
    required this.newGrams,
    required this.newItems,
    required this.dateKey,
  });
}

class _EntrySnapshotArgs {
  final DayEntry entry;
  final String dateKey;
  const _EntrySnapshotArgs({required this.entry, required this.dateKey});
}

class _CreateMealArgs {
  final MealDefinition draft;
  const _CreateMealArgs({required this.draft});
}

class _DeleteMealArgs {
  final String mealId;
  const _DeleteMealArgs({required this.mealId});
}

class _LogCustomComponentArgs {
  final String name;
  final Macros per100;
  final double grams;
  final MealSlot slot;
  const _LogCustomComponentArgs({
    required this.name,
    required this.per100,
    required this.grams,
    required this.slot,
  });
}
