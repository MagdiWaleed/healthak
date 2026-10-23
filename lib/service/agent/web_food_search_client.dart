import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../l10n/app_strings.dart';

import 'agent_models.dart';
import 'ai_client.dart' show kXaiDirectKey;

/// A grounded web lookup for one food's macros -- used only when
/// `search_foods` finds no catalog match. Never Firestore truth, only ever
/// surfaced to the model as "from the web", never written silently.
class WebFoodSearchResult {
  final String text;
  final List<String> sources;

  const WebFoodSearchResult({required this.text, required this.sources});
}

abstract interface class WebFoodSearchClient {
  Future<WebFoodSearchResult> search(String query);
}

/// Builds the client only when a direct xAI key is embedded, mirroring
/// [createAiClient] -- `null` when running against the (currently unused)
/// Cloud Functions proxy, since that path has no key to call xAI with here.
WebFoodSearchClient? createWebFoodSearchClient() => kXaiDirectKey.isNotEmpty
    ? XaiWebFoodSearchClient(apiKey: kXaiDirectKey)
    : null;

/// xAI's Live Search (`search_parameters` on `/v1/chat/completions`) was
/// deprecated in favor of a hosted `web_search` tool that only exists on the
/// newer `/v1/responses` endpoint -- a different request/response shape
/// entirely (`input` instead of `messages`, structured `output` items
/// instead of chat deltas). Rather than fork the whole streaming
/// conversation client onto that endpoint, this is one isolated, one-shot,
/// non-streaming call the registry makes when `search_food_online` runs; the
/// main chat loop never touches it.
///
/// Uses an explicit search-capable model instead of relying on an implicit
/// provider redirect from the lightweight chat model.
class XaiWebFoodSearchClient implements WebFoodSearchClient {
  final http.Client _http;
  final String _apiKey;
  final Uri _endpoint;

  XaiWebFoodSearchClient({
    required String apiKey,
    http.Client? httpClient,
    Uri? endpoint,
  })  : _apiKey = apiKey,
        _http = httpClient ?? http.Client(),
        _endpoint = endpoint ?? Uri.parse('https://api.x.ai/v1/responses');

  @override
  Future<WebFoodSearchResult> search(String query) async {
    final body = jsonEncode({
      'model': 'grok-4.3',
      'reasoning': {'effort': 'low'},
      'input': [
        {
          'role': 'user',
          'content':
              'Nutrition facts per 100g for: $query. State calories, protein, '
                  'carbs, and fat as plain numbers. Be brief. Cite sources.',
        },
      ],
      'tools': [
        {'type': 'web_search'},
      ],
      'stream': false,
      'max_output_tokens': 1200,
    });

    late final http.Response response;
    try {
      response = await _http
          .post(
            _endpoint,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const AgentException(
        AgentFailureKind.offline,
        'يحتاج البحث في الإنترنت إلى اتصال أفضل.',
      );
    } on SocketException {
      throw const AgentException(
        AgentFailureKind.offline,
        'يحتاج البحث في الإنترنت إلى اتصال أفضل.',
      );
    } on http.ClientException {
      throw const AgentException(
        AgentFailureKind.offline,
        'يحتاج البحث في الإنترنت إلى اتصال أفضل.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentException(
        response.statusCode == 429
            ? AgentFailureKind.quota
            : AgentFailureKind.server,
        'تعذّر البحث في الإنترنت الآن.',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is! Map<String, dynamic>) throw const FormatException();
      decoded = value;
    } on FormatException {
      throw const AgentException(
        AgentFailureKind.invalidResponse,
        'وصل رد غير مفهوم من البحث.',
      );
    }

    final output = decoded['output'];
    final texts = <String>[];
    final sources = <String>{};
    if (output is List) {
      for (final item in output) {
        if (item is! Map || item['type'] != 'message') continue;
        final content = item['content'];
        if (content is! List) continue;
        for (final part in content) {
          if (part is! Map || part['type'] != 'output_text') continue;
          final text = part['text'];
          if (text is String && text.trim().isNotEmpty) texts.add(text.trim());
          final annotations = part['annotations'];
          if (annotations is! List) continue;
          for (final annotation in annotations) {
            final url = annotation is Map ? annotation['url'] : null;
            if (url is String &&
                (Uri.tryParse(url)?.scheme == 'https' ||
                    Uri.tryParse(url)?.scheme == 'http')) {
              sources.add(url);
            }
          }
        }
      }
    }
    if (texts.isEmpty ||
        sources.isEmpty ||
        (decoded['status'] != null && decoded['status'] != 'completed')) {
      throw const AgentException(
          AgentFailureKind.invalidResponse, AppStrings.agentSearchIncomplete);
    }
    return WebFoodSearchResult(
        text: texts.join('\n'), sources: sources.take(5).toList());
  }
}
