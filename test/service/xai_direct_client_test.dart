import 'dart:convert';

import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/agent_tools.dart';
import 'package:diet_app2/service/agent/ai_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _sse(List<Map<String, dynamic>> events) =>
    '${events.map((e) => 'data: ${jsonEncode(e)}').join('\n\n')}\n\ndata: [DONE]\n\n';

void main() {
  const tools = AgentTools.readOnly;

  Future<List<AgentChunk>> collect(XaiDirectClient client) => client
      .agentTurn(turnId: 'turn-abcabcabc', messages: const [
        {'role': 'user', 'content': 'ماذا أكلت اليوم؟'}
      ], tools: tools)
      .toList();

  test('streams text, tool calls and usage from raw xAI SSE', () async {
    late http.Request captured;
    final client = XaiDirectClient(
      apiKey: 'test-key',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(_sse([
            {
              'choices': [
                {
                  'delta': {'content': 'أنت '}
                }
              ]
            },
            {
              'choices': [
                {
                  'delta': {'content': 'بخير'}
                }
              ]
            },
            {
              'choices': [
                {
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'call_1',
                        'function': {'name': 'get_today', 'arguments': ''}
                      }
                    ]
                  }
                }
              ]
            },
            {
              'choices': [
                {
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'function': {'arguments': '{}'}
                      }
                    ]
                  }
                }
              ]
            },
            {
              'choices': <dynamic>[],
              'usage': {'cost_in_usd_ticks': 5000000000}
            },
          ])),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    final chunks = await collect(client);

    expect(captured.url.host, 'api.x.ai');
    expect(captured.headers['authorization'], 'Bearer test-key');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'grok-3-mini');
    expect(body['reasoning_effort'], 'low');
    expect((body['messages'] as List).first, {
      'role': 'system',
      'content': isA<String>(),
    });

    final text = chunks.whereType<AgentTextDelta>().map((c) => c.text).join();
    expect(text, 'أنت بخير');
    final call = chunks.whereType<AgentToolCallChunk>().single.call;
    expect(call.name, 'get_today');
    expect(call.arguments, <String, dynamic>{});
    expect(chunks.whereType<AgentUsageChunk>().single.costUsd, closeTo(0.5, 1e-9));
    expect(chunks.last, isA<AgentDoneChunk>());
  });

  test('selected model rides through and omits reasoning_effort', () async {
    late http.Request captured;
    final client = XaiDirectClient(
      apiKey: 'k',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(_sse(const []), 200);
      }),
    );

    await client.agentTurn(
      turnId: 'turn-abcabcabc',
      messages: const [
        {'role': 'user', 'content': 'hi'}
      ],
      tools: const [],
      model: 'grok-4',
    ).toList();

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'grok-4');
    expect(body.containsKey('reasoning_effort'), isFalse);
    expect(body.containsKey('tools'), isFalse);
  });

  test('maps HTTP 401 to an unauthorized AgentException', () async {
    final client = XaiDirectClient(
      apiKey: 'bad',
      httpClient: MockClient((request) async => http.Response('no', 401)),
    );

    expect(
      () => collect(client),
      throwsA(isA<AgentException>().having(
        (e) => e.kind,
        'kind',
        AgentFailureKind.unauthorized,
      )),
    );
  });

  test('maps HTTP 429 to a quota AgentException', () async {
    final client = XaiDirectClient(
      apiKey: 'k',
      httpClient: MockClient((request) async => http.Response('slow down', 429)),
    );

    expect(
      () => collect(client),
      throwsA(isA<AgentException>().having(
        (e) => e.kind,
        'kind',
        AgentFailureKind.quota,
      )),
    );
  });
}
