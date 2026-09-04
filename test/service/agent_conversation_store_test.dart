import 'dart:convert';

import 'package:diet_app2/service/agent/agent_conversation_store.dart';
import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('keeps local chat for seven days and prunes older rows', () async {
    SharedPreferences.setMockInitialValues({
      'assistant.conversations.v1': jsonEncode({
        '2026-08-28': [_row('old', DateTime(2026, 8, 28))],
        '2026-08-29': [_row('kept', DateTime(2026, 8, 29))],
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPrefsAgentConversationStore(
      preferences: prefs,
      now: () => DateTime(2026, 9, 4, 12),
    );

    final loaded = await store.loadRecent();
    await store.save([
      ...loaded,
      ChatMessage(
        id: 'today',
        kind: ChatMessageKind.user,
        text: 'سؤال اليوم',
        createdAt: DateTime(2026, 9, 4, 12),
      ),
    ]);

    expect(loaded.map((message) => message.id), ['kept']);
    final persisted = jsonDecode(
      prefs.getString('assistant.conversations.v1')!,
    ) as Map<String, dynamic>;
    expect(persisted.keys, containsAll(['2026-08-29', '2026-09-04']));
    expect(persisted, isNot(contains('2026-08-28')));
  });
}

Map<String, dynamic> _row(String id, DateTime createdAt) => {
      'id': id,
      'kind': ChatMessageKind.assistant.name,
      'status': ChatMessageStatus.complete.name,
      'text': id,
      'createdAt': createdAt.toIso8601String(),
    };
