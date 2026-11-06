import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../l10n/app_strings.dart';

import 'agent_models.dart';
import 'ai_client.dart' show kXaiDirectKey;
import 'web_source.dart';
export 'web_source.dart';

/// Focus controls the search instruction, not the provider or model.
enum WebSearchFocus { nutrition, fitness, general }

class WebSearchResult {
  final String summary;
  final List<WebSource> sources;
  const WebSearchResult({required this.summary, required this.sources});
}

abstract interface class WebSearchClient {
  Future<WebSearchResult> search(String query, WebSearchFocus focus);
}

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

/// One-shot xAI Responses call with hosted web_search and grounded citations.
class XaiWebSearchClient implements WebSearchClient {
  final http.Client _http;
  final String _apiKey;
  final Uri _endpoint;

  XaiWebSearchClient({
    required String apiKey,
    http.Client? httpClient,
    Uri? endpoint,
  })  : _apiKey = apiKey,
        _http = httpClient ?? http.Client(),
        _endpoint = endpoint ?? Uri.parse('https://api.x.ai/v1/responses');

  @override
  Future<WebSearchResult> search(String query, WebSearchFocus focus) async {
    final body = jsonEncode({
      'model': 'grok-4.3',
      'reasoning': {'effort': 'low'},
      'input': [
        {
          'role': 'user',
          'content': '${switch (focus) {
            WebSearchFocus.nutrition =>
              'For food macros report values per 100g. For other nutrition questions explain evidence and limits.',
            WebSearchFocus.fitness =>
              'Explain fitness and exercise technique with relevant safety cautions.',
            WebSearchFocus.general =>
              'Answer the question using sourced facts.',
          }} Query: $query. Be brief. Cite sources.',
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
    final sources = <String, WebSource>{};
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
              sources.putIfAbsent(
                  url,
                  () => WebSource(
                      url: url,
                      title: annotation['title'] is String
                          ? annotation['title'] as String
                          : null));
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
    return WebSearchResult(
        summary: texts.join('\n'), sources: sources.values.take(5).toList());
  }
}

WebSearchClient? createWebSearchClient() =>
    kXaiDirectKey.isNotEmpty ? XaiWebSearchClient(apiKey: kXaiDirectKey) : null;

class XaiWebFoodSearchClient implements WebFoodSearchClient {
  final XaiWebSearchClient _delegate;
  XaiWebFoodSearchClient(
      {required String apiKey, http.Client? httpClient, Uri? endpoint})
      : _delegate = XaiWebSearchClient(
            apiKey: apiKey, httpClient: httpClient, endpoint: endpoint);
  @override
  Future<WebFoodSearchResult> search(String query) async {
    final result = await _delegate.search(query, WebSearchFocus.nutrition);
    return WebFoodSearchResult(
        text: result.summary,
        sources: result.sources.map((s) => s.url).toList());
  }
}
