import 'dart:io';
import 'package:diet_app2/service/agent/agent_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

String _lf(String s) => s.replaceAll('\r\n', '\n');

void main() {
  test('Dart and Cloud Function prompts are byte-identical and complete', () {
    // Normalize line endings: Git may check out CRLF on Windows.
    final js = _lf(File('functions/index.js').readAsStringSync());
    final match = RegExp(r'const systemPrompt = `([\s\S]*?)`;').firstMatch(js);
    expect(match, isNotNull);
    expect(_lf(kAgentSystemPrompt), match!.group(1));
    expect(kAgentSystemPrompt, isNot(contains('بعد استدعاء\n')));
    expect(kAgentSystemPrompt, contains('search_web'));
  });
}
