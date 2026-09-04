import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/food/food_item.dart';
import 'package:diet_app2/domain/meal/meal_definition.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/service/agent/agent_action_log.dart';
import 'package:diet_app2/service/agent/agent_data_source.dart';
import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/agent_proposal.dart';
import 'package:diet_app2/service/agent/agent_tool_registry.dart';
import 'package:diet_app2/service/agent/agent_tools.dart';
import 'package:diet_app2/service/agent/ai_client.dart';
import 'package:diet_app2/service/agent/agent_conversation_store.dart';
import 'package:diet_app2/service/agent/chat_orchestrator.dart';
import 'package:diet_app2/service/agent/chat_title_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('executes a read tool and streams the grounded follow-up', () async {
    final client = _ToolThenAnswerClient();
    final orchestrator = ChatOrchestrator(
      client: client,
      tools: AgentToolRegistry(data: _EmptyData()),
    );

    await orchestrator.send('كيف كان يومي؟');

    expect(client.calls, 2);
    expect(orchestrator.sending.value, isFalse);
    expect(
      orchestrator.messages.map((message) => message.kind),
      containsAll(<ChatMessageKind>[
        ChatMessageKind.user,
        ChatMessageKind.working,
        ChatMessageKind.assistant,
      ]),
    );
    expect(orchestrator.messages.last.text, 'لا يوجد تسجيل لليوم حتى الآن.');
    expect(orchestrator.messages.last.status, ChatMessageStatus.complete);
    expect(orchestrator.lastTurnCostUsd.value, closeTo(0.0002, 0.000001));
    expect(
      client.secondMessages.any(
        (message) =>
            message['role'] == 'tool' &&
            (message['content'] as String).contains('empty'),
      ),
      isTrue,
    );
  });

  test('passes the resolved model through to the client', () async {
    final client = _ToolThenAnswerClient();
    final orchestrator = ChatOrchestrator(
      client: client,
      tools: AgentToolRegistry(data: _EmptyData()),
      resolveModel: () => 'grok-4-fast-non-reasoning',
    );

    await orchestrator.send('كيف كان يومي؟');

    expect(client.lastModel, 'grok-4-fast-non-reasoning');
  });

  test('turns a quota failure into a calm error message', () async {
    final orchestrator = ChatOrchestrator(
      client: _QuotaClient(),
      tools: AgentToolRegistry(data: _EmptyData()),
    );

    await orchestrator.send('سؤال');

    expect(orchestrator.lastFailure.value, AgentFailureKind.quota);
    expect(orchestrator.messages.last.status, ChatMessageStatus.error);
    expect(orchestrator.messages.last.text, contains('اليوم'));
  });

  group('chat sessions', () {
    late SharedPreferences prefs;
    late SharedPrefsAgentConversationStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = SharedPrefsAgentConversationStore(preferences: prefs);
    });

    test('the first message lazily creates a session and titles it from a fallback',
        () async {
      final orchestrator = ChatOrchestrator(
        client: _EchoClient(),
        tools: AgentToolRegistry(data: _EmptyData()),
        conversationStore: store,
      );

      await orchestrator.send('ما هو هدفي اليومي من البروتين؟');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(orchestrator.currentSessionId.value, isNotNull);
      expect(orchestrator.sessions, hasLength(1));
      expect(orchestrator.sessions.single.title,
          'ما هو هدفي اليومي من البروتين؟');
    });

    test('the AI-generated title wins over the fallback when a generator is set',
        () async {
      final orchestrator = ChatOrchestrator(
        client: _EchoClient(),
        tools: AgentToolRegistry(data: _EmptyData()),
        conversationStore: store,
        titleGenerator: const _FixedTitleGenerator('هدف البروتين اليومي'),
      );

      await orchestrator.send('ما هو هدفي اليومي من البروتين؟');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(orchestrator.sessions.single.title, 'هدف البروتين اليومي');
    });

    test('startNewSession clears the board without touching the previous thread',
        () async {
      final orchestrator = ChatOrchestrator(
        client: _EchoClient(),
        tools: AgentToolRegistry(data: _EmptyData()),
        conversationStore: store,
      );

      await orchestrator.send('السؤال الأول');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final firstSessionId = orchestrator.currentSessionId.value;

      await orchestrator.startNewSession();
      expect(orchestrator.messages, isEmpty);
      expect(orchestrator.currentSessionId.value, isNot(firstSessionId));

      await orchestrator.send('السؤال الثاني');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(orchestrator.sessions, hasLength(2));
    });

    test('openSession restores a previous thread\'s messages', () async {
      final orchestrator = ChatOrchestrator(
        client: _EchoClient(),
        tools: AgentToolRegistry(data: _EmptyData()),
        conversationStore: store,
      );

      await orchestrator.send('السؤال الأول');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final firstSessionId = orchestrator.currentSessionId.value!;

      await orchestrator.startNewSession();
      await orchestrator.send('السؤال الثاني');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await orchestrator.openSession(firstSessionId);

      expect(orchestrator.currentSessionId.value, firstSessionId);
      expect(
        orchestrator.messages.any((m) => m.text == 'السؤال الأول'),
        isTrue,
      );
    });

    test('deleteSession removes it and falls back to the next most recent',
        () async {
      final orchestrator = ChatOrchestrator(
        client: _EchoClient(),
        tools: AgentToolRegistry(data: _EmptyData()),
        conversationStore: store,
      );

      await orchestrator.send('السؤال الأول');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final firstSessionId = orchestrator.currentSessionId.value!;

      await orchestrator.startNewSession();
      await orchestrator.send('السؤال الثاني');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final secondSessionId = orchestrator.currentSessionId.value!;

      await orchestrator.deleteSession(secondSessionId);

      expect(orchestrator.sessions.map((s) => s.id), [firstSessionId]);
      expect(orchestrator.currentSessionId.value, firstSessionId);
    });

    test('a restored orchestrator opens the most recently active session',
        () async {
      final first = ChatOrchestrator(
        client: _EchoClient(),
        tools: AgentToolRegistry(data: _EmptyData()),
        conversationStore: store,
      );
      await first.send('محادثة سابقة');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final restarted = ChatOrchestrator(
        client: _EchoClient(),
        tools: AgentToolRegistry(data: _EmptyData()),
        conversationStore: store,
      );
      restarted.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        restarted.messages.any((m) => m.text == 'محادثة سابقة'),
        isTrue,
      );
    });
  });

  group('agent action log', () {
    test('confirming a proposal records it, and undoing it marks it undone',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final actionLog = SharedPrefsAgentActionLog(preferences: prefs);
      final registry = AgentToolRegistry(data: _FoodOnlyData());
      final orchestrator = ChatOrchestrator(
        client: _EchoClient(),
        tools: registry,
        actionLog: actionLog,
      );

      final result = await registry.run(const AgentToolCall(
        id: 'call-1',
        name: 'propose_log_food',
        arguments: {'food_id': 'food-1', 'grams': 100},
      ));
      orchestrator.messages.add(ChatMessage(
        id: 'p1',
        kind: ChatMessageKind.proposal,
        status: ChatMessageStatus.pendingConfirm,
        text: result.proposal!.titleAr,
        proposal: result.proposal,
        createdAt: DateTime.now(),
      ));

      await orchestrator.confirmProposal('p1');

      final afterConfirm = await actionLog.list();
      expect(afterConfirm, hasLength(1));
      expect(afterConfirm.single.kind, ProposalKind.logFood);
      expect(afterConfirm.single.isUndoable, isTrue);

      final receiptMessage =
          orchestrator.messages.firstWhere((m) => m.kind == ChatMessageKind.receipt);
      await orchestrator.undoReceipt(receiptMessage.id);

      final afterUndo = await actionLog.list();
      // The original confirm entry is now marked undone, and the undo
      // itself landed as its own new entry ("an undo is itself a logged
      // action") -- two rows total.
      expect(afterUndo, hasLength(2));
      expect(afterUndo.firstWhere((e) => e.id == afterConfirm.single.id).isUndone,
          isTrue);
    });
  });
}

/// Answers every turn immediately with a fixed reply, no tool calls -- for
/// tests that only care about session bookkeeping, not the tool loop.
class _EchoClient implements AiClient {
  @override
  Stream<AgentChunk> agentTurn({
    required String turnId,
    required List<Map<String, dynamic>> messages,
    required List<AgentToolDefinition> tools,
    String? model,
    String? knownCatalog,
  }) async* {
    yield const AgentTextDelta('تمام.');
    yield const AgentDoneChunk();
  }
}

class _FixedTitleGenerator implements ChatTitleGenerator {
  final String title;
  const _FixedTitleGenerator(this.title);

  @override
  Future<String?> generateTitle(String firstUserMessage) async => title;
}

/// A minimal writable data source carrying exactly one catalog food and a
/// mutable day -- enough to run `propose_log_food` end to end.
class _FoodOnlyData implements AgentDataSource {
  static const _food = FoodItem(
    id: 'food-1',
    name: 'صدر دجاج',
    per100: Macros(protein: 31, carbs: 0, fat: 3.6),
  );

  DayLog? _day;

  @override
  String get uid => 'user-1';

  @override
  Future<DayLog?> getDay(DateTime date) async => _day;

  @override
  Future<DayLog?> getDayByKey(String dateKey) async =>
      _day?.dateKey == dateKey ? _day : null;

  @override
  Future<List<DayLog>> getHistory(DateTime start, DateTime end) async => const [];

  @override
  Future<List<MealDefinition>> getMeals() async => const [];

  @override
  Future<UserProfile?> getProfile() async => null;

  @override
  Future<List<FoodItem>> searchFoods(String query) async => const [_food];

  @override
  Future<List<FoodItem>> getPersonalFoods() async => const [];

  @override
  Future<DayLog> ensureDay(DateTime date, NutritionTargets targets) async {
    _day ??= DayLog.empty(date, targets);
    return _day!;
  }

  @override
  Future<void> upsertDayEntry(String dateKey, DayEntry entry) async {
    final current = _day;
    if (current == null || current.dateKey != dateKey) {
      throw StateError('Day $dateKey does not exist');
    }
    _day = current.withEntry(entry);
  }

  @override
  Future<void> removeDayEntry(String dateKey, String entryId) async {
    final current = _day;
    if (current == null) return;
    _day = current.withoutEntry(entryId);
  }

  @override
  Future<FoodItem?> getFoodById(String id) async => id == _food.id ? _food : null;

  @override
  Future<FoodItem> createPersonalFood(FoodItem draft) async =>
      draft.withId('personal-1');

  @override
  Future<MealDefinition?> getMealById(String id) async => null;

  @override
  Future<MealDefinition> saveMeal(MealDefinition draft) async => draft;

  @override
  Future<void> deleteMeal(String id) async {}
}

class _ToolThenAnswerClient implements AiClient {
  int calls = 0;
  List<Map<String, dynamic>> secondMessages = const [];
  String? lastModel;

  @override
  Stream<AgentChunk> agentTurn({
    required String turnId,
    required List<Map<String, dynamic>> messages,
    required List<AgentToolDefinition> tools,
    String? model,
    String? knownCatalog,
  }) async* {
    lastModel = model;
    calls++;
    if (calls == 1) {
      yield const AgentToolCallChunk(AgentToolCall(
        id: 'tool-call-1',
        name: 'get_today',
        arguments: {},
      ));
      yield const AgentDoneChunk();
      return;
    }
    secondMessages = messages;
    yield const AgentTextDelta('لا يوجد تسجيل ');
    yield const AgentTextDelta('لليوم حتى الآن.');
    yield const AgentUsageChunk(costUsd: 0.0002);
    yield const AgentDoneChunk();
  }
}

class _QuotaClient implements AiClient {
  @override
  Stream<AgentChunk> agentTurn({
    required String turnId,
    required List<Map<String, dynamic>> messages,
    required List<AgentToolDefinition> tools,
    String? model,
    String? knownCatalog,
  }) async* {
    throw const AgentException(
      AgentFailureKind.quota,
      'بلغت الحد اليومي. يمكنك المتابعة غدًا.',
    );
  }
}

class _EmptyData implements AgentDataSource {
  @override
  String get uid => 'user-1';

  @override
  Future<DayLog?> getDay(DateTime date) async => null;

  @override
  Future<DayLog?> getDayByKey(String dateKey) async => null;

  @override
  Future<List<DayLog>> getHistory(DateTime start, DateTime end) async =>
      const [];

  @override
  Future<List<MealDefinition>> getMeals() async => const [];

  @override
  Future<UserProfile?> getProfile() async => null;

  @override
  Future<List<FoodItem>> searchFoods(String query) async => const [];

  @override
  Future<List<FoodItem>> getPersonalFoods() async => const [];

  @override
  Future<DayLog> ensureDay(DateTime date, NutritionTargets targets) async =>
      DayLog.empty(date, targets);

  @override
  Future<void> upsertDayEntry(String dateKey, DayEntry entry) async {}

  @override
  Future<void> removeDayEntry(String dateKey, String entryId) async {}

  @override
  Future<FoodItem?> getFoodById(String id) async => null;

  @override
  Future<FoodItem> createPersonalFood(FoodItem draft) async =>
      draft.withId('food-created');

  @override
  Future<MealDefinition?> getMealById(String id) async => null;

  @override
  Future<MealDefinition> saveMeal(MealDefinition draft) async => draft;

  @override
  Future<void> deleteMeal(String id) async {}
}
