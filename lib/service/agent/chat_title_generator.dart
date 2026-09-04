import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_client.dart' show kXaiDirectKey;

/// Turns a user's first message into a short chat title -- the same idea as
/// ChatGPT's sidebar. A separate one-shot, non-streaming call so it never
/// shares the main assistant persona/system prompt or the conversation's
/// tool-calling context.
abstract interface class ChatTitleGenerator {
  /// Returns `null` on any failure (offline, bad response, empty text) --
  /// callers fall back to a plain truncation of the message, never block on
  /// this or surface an error for it.
  Future<String?> generateTitle(String firstUserMessage);
}

ChatTitleGenerator? createChatTitleGenerator() =>
    kXaiDirectKey.isNotEmpty ? XaiChatTitleGenerator(apiKey: kXaiDirectKey) : null;

class XaiChatTitleGenerator implements ChatTitleGenerator {
  final http.Client _http;
  final String _apiKey;
  final Uri _endpoint;

  XaiChatTitleGenerator({
    required String apiKey,
    http.Client? httpClient,
    Uri? endpoint,
  })  : _apiKey = apiKey,
        _http = httpClient ?? http.Client(),
        _endpoint = endpoint ?? Uri.parse('https://api.x.ai/v1/chat/completions');

  @override
  Future<String?> generateTitle(String firstUserMessage) async {
    final trimmed = firstUserMessage.trim();
    if (trimmed.isEmpty) return null;

    final body = jsonEncode({
      'model': 'grok-3-mini',
      'reasoning_effort': 'low',
      'messages': [
        {
          'role': 'system',
          'content':
              'لخّص رسالة المستخدم التالية في عنوان محادثة قصير جدًا بالعربية '
                  'الفصحى، بين كلمتين وخمس كلمات، بدون علامات اقتباس وبدون '
                  'نقطة في النهاية وبدون أي شرح إضافي. اكتب العنوان فقط.',
        },
        {'role': 'user', 'content': trimmed},
      ],
      'stream': false,
      'max_tokens': 24,
    });

    try {
      final response = await _http
          .post(
            _endpoint,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      final choices = decoded['choices'];
      final message =
          (choices is List && choices.isNotEmpty) ? (choices.first as Map)['message'] : null;
      final content = (message is Map) ? message['content'] : null;
      if (content is! String) return null;

      final title = content
          .trim()
          .replaceAll('"', '')
          .replaceAll('«', '')
          .replaceAll('»', '')
          .replaceAll('\n', ' ');
      if (title.isEmpty) return null;
      return title.length > 60 ? title.substring(0, 60) : title;
    } on Object {
      return null;
    }
  }
}
