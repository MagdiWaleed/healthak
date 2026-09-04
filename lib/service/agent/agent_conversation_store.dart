import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'agent_models.dart';

abstract interface class AgentConversationStore {
  Future<List<ChatMessage>> loadRecent();
  Future<void> save(List<ChatMessage> messages);
}

/// Device-only assistant history. No conversation content is written to
/// Firestore; completed messages are grouped by local day and retained for
/// seven days.
class SharedPrefsAgentConversationStore implements AgentConversationStore {
  static const _key = 'assistant.conversations.v1';
  static const _retentionDays = 7;

  final SharedPreferences? _preferences;
  final DateTime Function() _now;

  SharedPrefsAgentConversationStore({
    SharedPreferences? preferences,
    DateTime Function()? now,
  })  : _preferences = preferences,
        _now = now ?? DateTime.now;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  @override
  Future<List<ChatMessage>> loadRecent() async {
    final prefs = await _prefs;
    final days = _decode(prefs.getString(_key));
    final kept = _prune(days);
    if (kept.length != days.length) await _write(prefs, kept);

    final messages = <ChatMessage>[];
    for (final rows in kept.values) {
      for (final row in rows) {
        final message = _messageFromJson(row);
        if (message != null) messages.add(message);
      }
    }
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  @override
  Future<void> save(List<ChatMessage> messages) async {
    final prefs = await _prefs;
    final days = _prune(_decode(prefs.getString(_key)));
    final today = _dateKey(_now());
    days[today] = [
      for (final message in messages)
        if (_dateKey(message.createdAt) == today &&
            message.status != ChatMessageStatus.streaming &&
            // A pending card cannot be confirmed after a restart -- it
            // would render non-functional, so it never persists in the
            // first place. Resolved ones (confirmed/cancelled) are plain
            // history and persist normally.
            !(message.kind == ChatMessageKind.proposal &&
                message.status == ChatMessageStatus.pendingConfirm))
          _messageToJson(message),
    ];
    await _write(prefs, days);
  }

  Map<String, List<Map<String, dynamic>>> _prune(
    Map<String, List<Map<String, dynamic>>> days,
  ) {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final oldest = today.subtract(const Duration(days: _retentionDays - 1));
    return {
      for (final entry in days.entries)
        if (_parseDateKey(entry.key) case final date?
            when !date.isBefore(oldest) && !date.isAfter(today))
          entry.key: entry.value,
    };
  }

  static Map<String, List<Map<String, dynamic>>> _decode(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return {
        for (final entry in decoded.entries)
          entry.key: [
            for (final row in entry.value as List<dynamic>)
              (row as Map).cast<String, dynamic>(),
          ],
      };
    } on Object {
      return {};
    }
  }

  static Future<void> _write(
    SharedPreferences prefs,
    Map<String, List<Map<String, dynamic>>> days,
  ) =>
      prefs.setString(_key, jsonEncode(days));

  static Map<String, dynamic> _messageToJson(ChatMessage message) => {
        'id': message.id,
        'kind': message.kind.name,
        'status': message.status.name,
        'text': message.text,
        'toolName': message.toolName,
        'createdAt': message.createdAt.toIso8601String(),
      };

  static ChatMessage? _messageFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final text = json['text'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (id is! String || text is! String || createdAt == null) return null;
    final kind = ChatMessageKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => ChatMessageKind.notice,
    );
    final status = ChatMessageStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => ChatMessageStatus.complete,
    );
    return ChatMessage(
      id: id,
      kind: kind,
      status: status,
      text: text,
      toolName: json['toolName'] as String?,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDateKey(String value) => DateTime.tryParse(value);

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
