import 'dart:convert';

import 'package:diet_app2/service/agent/agent_conversation_store.dart';
import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/chat_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('round-trips a session\'s messages and metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsAgentConversationStore(preferences: prefs);

    await store.upsertSession(ChatSession(
      id: 's1',
      title: 'عنوان تجريبي',
      createdAt: DateTime(2026, 9, 4),
      updatedAt: DateTime(2026, 9, 4),
    ));
    await store.saveMessages('s1', [
      ChatMessage(
        id: 'm1',
        kind: ChatMessageKind.user,
        text: 'سؤال',
        createdAt: DateTime(2026, 9, 4),
      ),
    ]);

    final sessions = await store.listSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.title, 'عنوان تجريبي');

    final messages = await store.loadMessages('s1');
    expect(messages.single.text, 'سؤال');
  });

  test('newest session sorts first', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsAgentConversationStore(preferences: prefs);

    await store.upsertSession(ChatSession(
      id: 'old',
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    ));
    await store.upsertSession(ChatSession(
      id: 'new',
      createdAt: DateTime(2026, 9, 4),
      updatedAt: DateTime(2026, 9, 4),
    ));

    final sessions = await store.listSessions();
    expect(sessions.map((s) => s.id), ['new', 'old']);
  });

  test('never persists a pending (unresolved) proposal card', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsAgentConversationStore(preferences: prefs);

    await store.saveMessages('s1', [
      ChatMessage(
        id: 'm1',
        kind: ChatMessageKind.proposal,
        status: ChatMessageStatus.pendingConfirm,
        text: 'اقتراح',
        createdAt: DateTime(2026, 9, 4),
      ),
      ChatMessage(
        id: 'm2',
        kind: ChatMessageKind.receipt,
        text: 'تم',
        createdAt: DateTime(2026, 9, 4),
      ),
    ]);

    final messages = await store.loadMessages('s1');
    expect(messages.map((m) => m.id), ['m2']);
  });

  test('deleting a session removes it from the index and drops its messages',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsAgentConversationStore(preferences: prefs);

    await store.upsertSession(ChatSession(
      id: 's1',
      createdAt: DateTime(2026, 9, 4),
      updatedAt: DateTime(2026, 9, 4),
    ));
    await store.saveMessages('s1', [
      ChatMessage(
        id: 'm1',
        kind: ChatMessageKind.user,
        text: 'سؤال',
        createdAt: DateTime(2026, 9, 4),
      ),
    ]);

    await store.deleteSession('s1');

    expect(await store.listSessions(), isEmpty);
    expect(await store.loadMessages('s1'), isEmpty);
  });

  test('caps retained sessions and prunes the oldest', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsAgentConversationStore(preferences: prefs);

    for (var i = 0; i < 62; i++) {
      await store.upsertSession(ChatSession(
        id: 's$i',
        createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        updatedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
      ));
    }

    final sessions = await store.listSessions();
    expect(sessions.length, 60);
    expect(sessions.map((s) => s.id), isNot(contains('s0')));
    expect(sessions.map((s) => s.id), contains('s61'));
  });

  test('decodes a legacy row shape without toolName gracefully', () async {
    SharedPreferences.setMockInitialValues({
      'assistant.session.s1': jsonEncode([
        {
          'id': 'm1',
          'kind': 'assistant',
          'status': 'complete',
          'text': 'رد قديم',
          'createdAt': DateTime(2026, 9, 1).toIso8601String(),
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsAgentConversationStore(preferences: prefs);

    final messages = await store.loadMessages('s1');
    expect(messages.single.text, 'رد قديم');
  });
}
