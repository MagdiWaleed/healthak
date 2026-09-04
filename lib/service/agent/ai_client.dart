import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'agent_model_catalog.dart';
import 'agent_models.dart';
import 'agent_prompt.dart';
import 'agent_tools.dart';

const String kAgentProxyUrl = String.fromEnvironment(
  'AI_PROXY_URL',
  defaultValue:
      'https://us-central1-diet-app-a908a.cloudfunctions.net/agentTurn',
);

/// A direct xAI key, supplied at build time via
/// `--dart-define=XAI_API_KEY=...` (or `--dart-define-from-file`). When set, the
/// app calls xAI directly and skips the Cloud Functions proxy. The key is
/// embedded in the binary and is extractable — only use with a spend cap on the
/// xAI account. Empty by default.
const String kXaiDirectKey = String.fromEnvironment('XAI_API_KEY');

const Duration _kAgentTimeout = Duration(seconds: 25);
const String _kXaiEndpoint = 'https://api.x.ai/v1/chat/completions';
const int _kMaxResponseTokens = 800;

abstract interface class AiClient {
  Stream<AgentChunk> agentTurn({
    required String turnId,
    required List<Map<String, dynamic>> messages,
    required List<AgentToolDefinition> tools,
    String? model,
  });
}

/// Chooses the direct client when a build-time key is present, otherwise the
/// authenticated Cloud Functions proxy.
AiClient createAiClient() =>
    kXaiDirectKey.isNotEmpty ? XaiDirectClient(apiKey: kXaiDirectKey) : XaiProxyClient();

const _offlineError = AgentException(
  AgentFailureKind.offline,
  'يحتاج المساعد إلى اتصال بالإنترنت.',
);

AgentException _statusError(int status) {
  if (status == 401 || status == 403) {
    return const AgentException(
      AgentFailureKind.unauthorized,
      'انتهت جلسة الدخول. سجّل الدخول مرة أخرى.',
    );
  }
  if (status == 429) {
    return const AgentException(
      AgentFailureKind.quota,
      'بلغت الحد اليومي. يمكنك المتابعة غدًا.',
    );
  }
  return AgentException(
    AgentFailureKind.server,
    'تعذّر تشغيل المساعد ($status).',
  );
}

/// Calls the authenticated Firebase proxy, which owns the key and streams
/// already-normalized SSE events.
class XaiProxyClient implements AiClient {
  final FirebaseAuth _auth;
  final http.Client _http;
  final Uri endpoint;

  XaiProxyClient({
    FirebaseAuth? auth,
    http.Client? httpClient,
    Uri? endpoint,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _http = httpClient ?? http.Client(),
        endpoint = endpoint ?? Uri.parse(kAgentProxyUrl);

  @override
  Stream<AgentChunk> agentTurn({
    required String turnId,
    required List<Map<String, dynamic>> messages,
    required List<AgentToolDefinition> tools,
    String? model,
  }) async* {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AgentException(
        AgentFailureKind.unauthorized,
        'يلزم تسجيل الدخول لاستخدام المساعد.',
      );
    }

    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        throw const AgentException(
          AgentFailureKind.unauthorized,
          'انتهت جلسة الدخول. سجّل الدخول مرة أخرى.',
        );
      }
      final request = http.Request('POST', endpoint)
        ..headers.addAll({
          HttpHeaders.authorizationHeader: 'Bearer $token',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'text/event-stream',
        })
        ..body = jsonEncode({
          'turnId': turnId,
          if (model != null) 'model': model,
          'messages': messages,
          'tools': [for (final tool in tools) tool.toJson()],
        });

      final response = await _http.send(request).timeout(
            _kAgentTimeout,
            onTimeout: () => throw _offlineError,
          );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _statusError(response.statusCode);
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        final event = jsonDecode(payload) as Map<String, dynamic>;
        switch (event['type']) {
          case 'text_delta':
            final delta = event['text'];
            if (delta is String && delta.isNotEmpty) yield AgentTextDelta(delta);
          case 'tool_call':
            final id = event['id'];
            final name = event['name'];
            final arguments = event['arguments'];
            if (id is! String || name is! String || arguments is! Map) {
              throw const AgentException(
                AgentFailureKind.invalidResponse,
                'وصل رد غير مكتمل من المساعد.',
              );
            }
            yield AgentToolCallChunk(AgentToolCall(
              id: id,
              name: name,
              arguments: arguments.cast<String, dynamic>(),
            ));
          case 'usage':
            final cost = event['costUsd'];
            yield AgentUsageChunk(costUsd: cost is num ? cost.toDouble() : null);
          case 'done':
            yield const AgentDoneChunk();
          case 'error':
            throw AgentException(
              _failureKind(event['code'] as String?),
              event['messageAr'] as String? ??
                  'حدثت مشكلة أثناء تشغيل المساعد.',
            );
        }
      }
    } on AgentException {
      rethrow;
    } on TimeoutException {
      throw _offlineError;
    } on SocketException {
      throw _offlineError;
    } on http.ClientException {
      throw _offlineError;
    } on FormatException {
      throw const AgentException(
        AgentFailureKind.invalidResponse,
        'وصل رد غير مفهوم من المساعد.',
      );
    }
  }

  static AgentFailureKind _failureKind(String? code) => switch (code) {
        'quota_exceeded' => AgentFailureKind.quota,
        'unauthorized' => AgentFailureKind.unauthorized,
        'invalid_response' => AgentFailureKind.invalidResponse,
        'offline' => AgentFailureKind.offline,
        _ => AgentFailureKind.server,
      };
}

/// Calls xAI's OpenAI-compatible chat completions endpoint directly, with the
/// key embedded in the app. No server-side quota or premium gate — the xAI
/// account spend cap is the only ceiling.
class XaiDirectClient implements AiClient {
  final http.Client _http;
  final String _apiKey;
  final Uri _endpoint;

  XaiDirectClient({
    required String apiKey,
    http.Client? httpClient,
    Uri? endpoint,
  })  : _apiKey = apiKey,
        _http = httpClient ?? http.Client(),
        _endpoint = endpoint ?? Uri.parse(_kXaiEndpoint);

  @override
  Stream<AgentChunk> agentTurn({
    required String turnId,
    required List<Map<String, dynamic>> messages,
    required List<AgentToolDefinition> tools,
    String? model,
  }) async* {
    final resolved = AgentModels.byId(model);
    final body = <String, dynamic>{
      'model': resolved.id,
      if (resolved.reasoningEffort != null)
        'reasoning_effort': resolved.reasoningEffort,
      'messages': [
        {'role': 'system', 'content': kAgentSystemPrompt},
        ...messages,
      ],
      if (tools.isNotEmpty) 'tools': [for (final tool in tools) tool.toJson()],
      if (tools.isNotEmpty) 'tool_choice': 'auto',
      'parallel_tool_calls': true,
      'stream': true,
      'stream_options': {'include_usage': true},
      'max_tokens': _kMaxResponseTokens,
    };

    try {
      final request = http.Request('POST', _endpoint)
        ..headers.addAll({
          HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'text/event-stream',
        })
        ..body = jsonEncode(body);

      final response = await _http.send(request).timeout(
            _kAgentTimeout,
            onTimeout: () => throw _offlineError,
          );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _statusError(response.statusCode);
      }

      final calls = <int, _ToolCallDraft>{};
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;

        final Map<String, dynamic> event;
        try {
          event = jsonDecode(payload) as Map<String, dynamic>;
        } on FormatException {
          continue; // keep-alive or partial frame
        }

        final choices = event['choices'];
        final delta = (choices is List && choices.isNotEmpty)
            ? (choices.first as Map)['delta']
            : null;
        if (delta is Map) {
          final content = delta['content'];
          if (content is String && content.isNotEmpty) {
            yield AgentTextDelta(content);
          }
          final toolCalls = delta['tool_calls'];
          if (toolCalls is List) {
            for (final raw in toolCalls) {
              if (raw is! Map) continue;
              final index = (raw['index'] as num?)?.toInt() ?? 0;
              final draft = calls.putIfAbsent(index, _ToolCallDraft.new);
              final id = raw['id'];
              if (id is String && id.isNotEmpty) draft.id = id;
              final fn = raw['function'];
              if (fn is Map) {
                final name = fn['name'];
                if (name is String) draft.name += name;
                final args = fn['arguments'];
                if (args is String) draft.arguments += args;
              }
            }
          }
        }

        final ticks = (event['usage'] as Map?)?['cost_in_usd_ticks'];
        if (ticks is num) {
          yield AgentUsageChunk(costUsd: ticks.toDouble() / 1e10);
        }
      }

      for (final draft in calls.values) {
        final Map<String, dynamic> arguments;
        try {
          final decoded = jsonDecode(
            draft.arguments.isEmpty ? '{}' : draft.arguments,
          );
          arguments = decoded is Map
              ? decoded.cast<String, dynamic>()
              : <String, dynamic>{};
        } on FormatException {
          throw const AgentException(
            AgentFailureKind.invalidResponse,
            'وصل طلب أداة غير مكتمل من المساعد.',
          );
        }
        yield AgentToolCallChunk(AgentToolCall(
          id: draft.id.isEmpty ? 'call_${draft.name}' : draft.id,
          name: draft.name,
          arguments: arguments,
        ));
      }
      yield const AgentDoneChunk();
    } on AgentException {
      rethrow;
    } on TimeoutException {
      throw _offlineError;
    } on SocketException {
      throw _offlineError;
    } on http.ClientException {
      throw _offlineError;
    } on FormatException {
      throw const AgentException(
        AgentFailureKind.invalidResponse,
        'وصل رد غير مفهوم من المساعد.',
      );
    }
  }
}

class _ToolCallDraft {
  String id = '';
  String name = '';
  String arguments = '';
}
