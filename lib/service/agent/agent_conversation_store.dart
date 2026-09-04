import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'agent_models.dart';
import 'chat_session.dart';

abstract interface class AgentConversationStore {
  /// Newest-first.
  Future<List<ChatSession>> listSessions();
  Future<List<ChatMessage>> loadMessages(String sessionId);
  Future<void> saveMessages(String sessionId, List<ChatMessage> messages);
  Future<void> upsertSession(ChatSession session);
  Future<void> deleteSession(String sessionId);
}

/// Device-only assistant history, one row per conversation thread. No
/// conversation content is written to Firestore. At most [_maxSessions]
/// threads are kept locally -- saving one beyond that prunes the oldest by
/// `updatedAt`, deleting its message row too.
class SharedPrefsAgentConversationStore implements AgentConversationStore {
  static const _indexKey = 'assistant.sessions.v1';
  static const _messagesPrefix = 'assistant.session.';
  static const _maxSessions = 60;

  final SharedPreferences? _preferences;

  SharedPrefsAgentConversationStore({SharedPreferences? preferences})
      : _preferences = preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  @override
  Future<List<ChatSession>> listSessions() async {
    final prefs = await _prefs;
    final sessions = _decodeIndex(prefs.getString(_indexKey));
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  @override
  Future<List<ChatMessage>> loadMessages(String sessionId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_messagesPrefix$sessionId');
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final messages = <ChatMessage>[];
      for (final row in decoded) {
        final message = _messageFromJson((row as Map).cast<String, dynamic>());
        if (message != null) messages.add(message);
      }
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> saveMessages(String sessionId, List<ChatMessage> messages) async {
    final prefs = await _prefs;
    final rows = [
      for (final message in messages)
        if (message.status != ChatMessageStatus.streaming &&
            // A pending card cannot be confirmed after a restart -- it would
            // render non-functional, so it never persists in the first
            // place. Resolved ones (confirmed/cancelled) are plain history.
            !(message.kind == ChatMessageKind.proposal &&
                message.status == ChatMessageStatus.pendingConfirm))
          _messageToJson(message),
    ];
    await prefs.setString('$_messagesPrefix$sessionId', jsonEncode(rows));
  }

  @override
  Future<void> upsertSession(ChatSession session) async {
    final prefs = await _prefs;
    var sessions = _decodeIndex(prefs.getString(_indexKey))
      ..removeWhere((existing) => existing.id == session.id)
      ..add(session)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (sessions.length > _maxSessions) {
      final overflow = sessions.sublist(_maxSessions);
      sessions = sessions.sublist(0, _maxSessions);
      for (final dropped in overflow) {
        await prefs.remove('$_messagesPrefix${dropped.id}');
      }
    }

    await prefs.setString(
      _indexKey,
      jsonEncode([for (final s in sessions) s.toJson()]),
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final prefs = await _prefs;
    final sessions = _decodeIndex(prefs.getString(_indexKey))
      ..removeWhere((s) => s.id == sessionId);
    await prefs.setString(
      _indexKey,
      jsonEncode([for (final s in sessions) s.toJson()]),
    );
    await prefs.remove('$_messagesPrefix$sessionId');
  }

  static List<ChatSession> _decodeIndex(String? raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final row in decoded)
          ChatSession.fromJson((row as Map).cast<String, dynamic>()),
      ];
    } on Object {
      return [];
    }
  }

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
}
