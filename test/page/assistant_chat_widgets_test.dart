import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/assistant/assistant_tab.dart';
import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/web_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage message(ChatMessageKind kind, String text,
        {ChatMessageStatus status = ChatMessageStatus.complete,
        List<WebSource> sources = const []}) =>
    ChatMessage(
        id: text,
        kind: kind,
        text: text,
        status: status,
        sources: sources,
        createdAt: DateTime(2026));

Widget host(Widget child) => MaterialApp(
      home: Scaffold(
          body: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Center(
            child: SizedBox(
                width: 390,
                child: Directionality(
                    textDirection: TextDirection.rtl, child: child))),
      )),
    );

void main() {
  testWidgets('running tool chips collapse after completion', (tester) async {
    final tools = [
      message(ChatMessageKind.working, AppStrings.agentSearchingWeb,
          status: ChatMessageStatus.streaming),
      message(ChatMessageKind.working, AppStrings.agentReadingTraining),
    ];
    await tester.pumpWidget(host(AssistantToolActivity(messages: tools)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.agentSearchingWeb), findsOneWidget);
    expect(find.text(AppStrings.agentReadingTraining), findsOneWidget);
    await tester.pumpWidget(host(AssistantToolActivity(messages: [
      tools[0].copyWith(status: ChatMessageStatus.complete),
      tools[1],
    ])));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.agentToolsUsed(2)), findsOneWidget);
    expect(find.text(AppStrings.agentSearchingWeb), findsNothing);
    tester.widget<TextButton>(find.byType(TextButton)).onPressed!();
    await tester.pump();
    expect(find.text(AppStrings.agentSearchingWeb), findsOneWidget);
  });

  testWidgets('source chip passes URL to launcher callback', (tester) async {
    Uri? opened;
    await tester.pumpWidget(host(AssistantMessageCard(
      message: message(ChatMessageKind.assistant, 'إجابة',
          sources: const [WebSource(url: 'https://example.org/article')]),
      failure: null,
      onRetry: () {},
      openSource: (uri) async {
        opened = uri;
      },
    )));
    await tester.pumpAndSettle();
    tester.widget<ActionChip>(find.byType(ActionChip)).onPressed!();
    expect(opened.toString(), 'https://example.org/article');
  });

  testWidgets('empty suggestions send the chosen prompt', (tester) async {
    String? sent;
    await tester.pumpWidget(host(AssistantEmptyConversation(
      active: false,
      snapshot: 'لقطة اليوم: المتبقي من السعرات 800؛ البروتين 50 جم',
      onSelected: (prompt) async {
        sent = prompt;
      },
    )));
    expect(find.byType(ActionChip), findsNWidgets(4));
    await tester.tap(find.text(AppStrings.agentSuggestionProteinLeft));
    expect(sent, AppStrings.agentSuggestionProteinLeft);
  });
}
