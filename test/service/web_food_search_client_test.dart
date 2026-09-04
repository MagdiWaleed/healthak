import 'dart:convert';

import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/web_food_search_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses the /v1/responses output into text and citation sources',
      () async {
    late http.Request captured;
    final client = XaiWebFoodSearchClient(
      apiKey: 'test-key',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'model': 'grok-4.3',
            'output': [
              {'type': 'reasoning', 'summary': []},
              {'type': 'web_search_call', 'status': 'completed'},
              {
                'type': 'message',
                'role': 'assistant',
                'content': [
                  {
                    'type': 'output_text',
                    'text': '~60 kcal, 0.5g protein, 15g carbs, 0.2g fat per 100g.',
                    'annotations': [
                      {
                        'type': 'url_citation',
                        'url': 'https://example.com/a',
                      },
                      {
                        'type': 'url_citation',
                        'url': 'https://example.com/b',
                      },
                    ],
                  },
                ],
              },
            ],
          })),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.search('dragon fruit');

    expect(captured.url.path, '/v1/responses');
    expect(captured.headers['authorization'], 'Bearer test-key');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['tools'], [
      {'type': 'web_search'},
    ]);
    expect((body['input'] as List).single, isA<Map>());

    expect(result.text, contains('60 kcal'));
    expect(result.sources, ['https://example.com/a', 'https://example.com/b']);
  });

  test('maps HTTP 429 to a quota AgentException', () async {
    final client = XaiWebFoodSearchClient(
      apiKey: 'k',
      httpClient: MockClient((request) async => http.Response('slow', 429)),
    );

    expect(
      () => client.search('q'),
      throwsA(isA<AgentException>()
          .having((e) => e.kind, 'kind', AgentFailureKind.quota)),
    );
  });

  test('returns empty text/sources when the response has no message item',
      () async {
    final client = XaiWebFoodSearchClient(
      apiKey: 'k',
      httpClient: MockClient((request) async => http.Response(
            jsonEncode({'output': <dynamic>[]}),
            200,
          )),
    );

    final result = await client.search('q');

    expect(result.text, '');
    expect(result.sources, isEmpty);
  });
}
