import 'dart:io';
import 'package:diet_app2/service/agent/agent_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart and Cloud Function prompts are byte-identical and complete', () {
    final js = File('functions/index.js').readAsStringSync();
    final match = RegExp(r'const systemPrompt = `([\s\S]*?)`;').firstMatch(js);
    expect(match, isNotNull);
    expect(kAgentSystemPrompt, match!.group(1));
    expect(kAgentSystemPrompt, isNot(contains('بعد استدعاء\n')));
    expect(kAgentSystemPrompt, contains('search_web'));
  });
}
