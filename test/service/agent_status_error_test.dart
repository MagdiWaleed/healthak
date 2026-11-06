import 'dart:convert';

import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/ai_client.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<AgentException> failureFor(int status, String body) async {
    final client = XaiDirectClient(
      apiKey: 'test',
      httpClient: MockClient((_) async => http.Response(body, status)),
    );
    try {
      await client
          .agentTurn(turnId: 't', messages: const [], tools: const []).toList();
      throw StateError('Expected failure');
    } on AgentException catch (error) {
      return error;
    }
  }

  test('revoked key in a 400 body maps to unauthorized', () async {
    final error = await failureFor(400,
        '{"code":"invalid-argument","error":"Incorrect API key provided"}');
    expect(error.kind, AgentFailureKind.unauthorized);
    expect(error.message, contains('مفتاح'));
    expect(error.message, isNot(contains('400')));
  });

  for (final status in [401, 403]) {
    test('$status maps to unauthorized', () async {
      expect(
          (await failureFor(status, '{}')).kind, AgentFailureKind.unauthorized);
    });
  }

  test('403 permission-denied explains the missing chat permission', () async {
    final error = await failureFor(403,
        '{"code":"permission-denied","error":"Access to the chat endpoint is denied."}');
    expect(error.kind, AgentFailureKind.unauthorized);
    expect(error.message, AppStrings.agentKeyNoChatAccess);
  });

  test('429 maps to quota', () async {
    expect((await failureFor(429, '{}')).kind, AgentFailureKind.quota);
  });

  test('unknown failure keeps code as secondary text', () async {
    final error = await failureFor(500, '{}');
    expect(error.kind, AgentFailureKind.server);
    expect(error.message, contains('\n'));
    expect(error.message, contains('500'));
  });

  test('model 404 retries once with fallback model', () async {
    final models = <String>[];
    final client = XaiDirectClient(
      apiKey: 'test',
      httpClient: MockClient((request) async {
        models.add((jsonDecode(request.body) as Map)['model'] as String);
        if (models.length == 1) {
          return http.Response('{"error":"model not found"}', 404);
        }
        return http.Response('data: [DONE]\n\n', 200);
      }),
    );
    await client
        .agentTurn(
            turnId: 't', messages: const [], tools: const [], model: 'grok-4')
        .toList();
    expect(models, ['grok-4', 'grok-3-mini']);
  });

  test('fallback model failure shows friendly message', () async {
    final error = await failureFor(404, '{"error":"model not found"}');
    expect(error.message, 'النموذج غير متاح حاليًا.');
  });

  test('unrelated 404 keeps a generic error and secondary code', () async {
    final error = await failureFor(404, '{"error":"route missing"}');
    expect(error.message, contains('رمز الخطأ: 404'));
  });
}
