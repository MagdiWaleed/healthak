import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/food/food_item.dart';
import 'package:diet_app2/domain/meal/meal_definition.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/service/agent/agent_data_source.dart';
import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/agent_tool_registry.dart';
import 'package:diet_app2/service/agent/agent_tools.dart';
import 'package:diet_app2/service/agent/ai_client.dart';
import 'package:diet_app2/service/agent/chat_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

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
  }) async* {
    throw const AgentException(
      AgentFailureKind.quota,
      'بلغت الحد اليومي. يمكنك المتابعة غدًا.',
    );
  }
}

class _EmptyData implements AgentDataSource {
  @override
  Future<DayLog?> getDay(DateTime date) async => null;

  @override
  Future<List<DayLog>> getHistory(DateTime start, DateTime end) async =>
      const [];

  @override
  Future<List<MealDefinition>> getMeals() async => const [];

  @override
  Future<UserProfile?> getProfile() async => null;

  @override
  Future<List<FoodItem>> searchFoods(String query) async => const [];
}
