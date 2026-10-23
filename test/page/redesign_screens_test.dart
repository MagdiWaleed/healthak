import 'dart:io';
import 'dart:ui' as ui;

import 'package:diet_app2/domain/day/day_log.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/nutrition/macros.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/assistant/assistant_tab.dart';
import 'package:diet_app2/page/today/today_controller.dart';
import 'package:diet_app2/page/today/today_tab.dart';
import 'package:diet_app2/service/agent/agent_models.dart';
import 'package:diet_app2/service/agent/agent_proposal.dart';
import 'package:diet_app2/service/agent/chat_orchestrator.dart';
import 'package:diet_app2/service/prefs_service.dart';
import 'package:diet_app2/ui/glass/glass_scaffold.dart';
import 'package:diet_app2/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TodayFixture extends GetxController implements TodayController {
  @override
  final today = DateTime(2026, 10, 23).obs;
  @override
  final selectedDate = DateTime(2026, 10, 23).obs;
  @override
  final editingPast = false.obs;
  @override
  final loading = false.obs;
  @override
  final error = RxnString();
  @override
  final loggedDayKeys = Rx<Set<String>>({'2026-10-23'});
  @override
  final day = Rxn<DayLog>(DayLog(
    dateKey: '2026-10-23',
    date: DateTime(2026, 10, 23),
    targets: const NutritionTargets(
        mode: TargetMode.manual,
        kcal: 2000,
        macros: Macros(protein: 150, carbs: 225, fat: 55)),
    entries: const [
      DayEntry(
          entryId: 'breakfast',
          origin: DayEntryOrigin.quickAdd,
          name: 'زبادي بالشوفان',
          slot: MealSlot.breakfast,
          order: 0,
          eaten: true,
          items: [
            FrozenItem(
                foodId: 'oats',
                name: 'شوفان وزبادي',
                per100: Macros(protein: 12, carbs: 30, fat: 5),
                grams: 200)
          ]),
      DayEntry(
          entryId: 'lunch',
          origin: DayEntryOrigin.quickAdd,
          name: 'دجاج مع الأرز',
          slot: MealSlot.lunch,
          order: 1,
          items: [
            FrozenItem(
                foodId: 'chicken',
                name: 'صدر دجاج',
                per100: Macros(protein: 31, carbs: 0, fat: 4),
                grams: 150),
            FrozenItem(
                foodId: 'rice',
                name: 'أرز مطبوخ',
                per100: Macros(protein: 3, carbs: 28, fat: 1),
                grams: 200)
          ]),
    ],
  ));
  @override
  bool get isViewingToday =>
      DayLog.keyFor(selectedDate.value) == DayLog.keyFor(today.value);
  @override
  bool get canEditSelectedDay => isViewingToday || editingPast.value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatFixture extends GetxController implements ChatOrchestrator {
  @override
  final messages = <ChatMessage>[].obs;
  @override
  final sending = false.obs;
  @override
  final lastFailure = Rxn<AgentFailureKind>();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    Get.testMode = true;
  });
  tearDown(() {
    Get.reset();
  });

  Future<void> fonts() async {
    final loader = FontLoader('Cairo');
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('asset/font/Cairo-$name.ttf'));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  }

  Widget app(Widget child, GlobalKey boundary, {bool navigation = false}) =>
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        home: RepaintBoundary(
            key: boundary,
            child: navigation
                ? GlassScaffold(
                    body: child,
                    bottomNavigationBar: NavigationBar(destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.today), label: AppStrings.today),
                      NavigationDestination(
                          icon: Icon(Icons.restaurant_menu),
                          label: AppStrings.myMeals),
                      NavigationDestination(
                          icon: Icon(Icons.storefront),
                          label: AppStrings.market),
                      NavigationDestination(
                          icon: Icon(Icons.person_outline),
                          label: AppStrings.account),
                    ]))
                : child),
      );

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_REVIEW')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('output/review').create(recursive: true);
      await File('output/review/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'Today screen keeps meals reachable and assistant accessible without scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await fonts();
    Get.put<TodayController>(_TodayFixture());
    final key = GlobalKey();
    await tester.pumpWidget(app(const TodayTab(), key, navigation: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip(AppStrings.askAssistant).hitTestable(),
        findsOneWidget);
    expect(find.text(AppStrings.addMeal).hitTestable(), findsOneWidget);
    await capture(tester, key, 'today-implemented');
    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.text('دجاج مع الأرز').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant header and composer fit a narrow RTL screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await fonts();
    SharedPreferences.setMockInitialValues({
      'schemaVersion': 2,
      'assistantDisclosureAccepted': true,
      'assistantHeaderTourSeen': true
    });
    Get.put(await PrefsService().init());
    final chat = Get.put<ChatOrchestrator>(_ChatFixture());
    final key = GlobalKey();
    await tester.pumpWidget(app(const AssistantTab(), key));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    await capture(tester, key, 'assistant-implemented');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    tester.view.resetViewInsets();
    tester.testTextInput.hide();
    chat.messages.add(ChatMessage(
      id: 'proposal',
      kind: ChatMessageKind.proposal,
      text: '',
      status: ChatMessageStatus.pendingConfirm,
      createdAt: DateTime(2026, 10, 23),
      proposal: const Proposal(
          id: 'proposal',
          toolCallId: 'call',
          kind: ProposalKind.logFood,
          titleAr: 'إضافة ١٥٠ جرام دجاج للغداء',
          dateKey: '2026-10-23',
          card: {
            'macros': {'kcal': 240, 'protein_g': 46.5, 'carbs_g': 0, 'fat_g': 6}
          },
          modelSummary: {},
          execArgs: 'display fixture'),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.assistantConfirmNote), findsOneWidget);
    expect(find.text(AppStrings.assistantConfirm), findsOneWidget);
    await capture(tester, key, 'assistant-proposal-implemented');
    await tester.tap(find.byTooltip(AppStrings.assistantOptions));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.assistantNewChat), findsOneWidget);
    expect(find.text(AppStrings.assistantModelPickerTooltip), findsOneWidget);
  });
}
