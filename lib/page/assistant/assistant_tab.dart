import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/day/day_log.dart';
import '../../l10n/app_strings.dart';
import '../../service/agent/agent_model_catalog.dart';
import '../../service/agent/agent_models.dart';
import '../../service/agent/agent_proposal.dart';
import '../../service/agent/chat_orchestrator.dart';
import '../../service/prefs_service.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/format/number_input.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/components/shimmer_box.dart';
import '../../ui/motion/motion.dart';
import '../../ui/motion/navigation.dart';
import '../../ui/motion/pressable.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/glass_tokens.dart';
import '../../ui/theme/motion_settings.dart';
import '../history_ai/agent_history_screen.dart';

part 'widgets/header.dart';
part 'widgets/composer.dart';
part 'widgets/messages.dart';
part 'widgets/proposals.dart';
part 'widgets/activity.dart';

class AssistantTab extends StatefulWidget {
  const AssistantTab({super.key});

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  late final ChatOrchestrator orchestrator = Get.find<ChatOrchestrator>();
  late final PrefsService prefs = Get.find<PrefsService>();
  final composer = TextEditingController();
  final scroll = ScrollController();
  Worker? _messageWorker;
  late bool disclosureAccepted;
  late bool headerTourSeen;
  String? todaySnapshot;

  @override
  void initState() {
    super.initState();
    disclosureAccepted = prefs.assistantDisclosureAccepted;
    headerTourSeen = prefs.assistantHeaderTourSeen;
    _messageWorker = ever(orchestrator.messages, (_) => _scrollToEnd());
    orchestrator.todaySnapshotForSuggestions().then((snapshot) {
      if (mounted) setState(() => todaySnapshot = snapshot);
    });
  }

  @override
  void dispose() {
    _messageWorker?.dispose();
    composer.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      if (!MotionSettings.enabled(context)) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        return;
      }
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: MotionSettings.duration(
          context,
          const Duration(milliseconds: 240),
        ),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _acceptDisclosure() async {
    await prefs.acceptAssistantDisclosure();
    if (mounted) setState(() => disclosureAccepted = true);
  }

  Future<void> _dismissHeaderTour() async {
    if (mounted) setState(() => headerTourSeen = true);
    await prefs.dismissAssistantHeaderTour();
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? composer.text).trim();
    if (text.isEmpty || orchestrator.sending.value) return;
    composer.clear();
    FocusScope.of(context).unfocus();
    await orchestrator.send(text);
  }

  // Pushed as its own page now (no longer a bottom-nav tab), so it owns its
  // full-screen chrome the same way `MealEditorScreen`/`FoodDetailScreen` do
  // -- and the composer no longer needs to clear a shared nav bar/FAB
  // underneath it, just the device's own bottom safe area.
  @override
  Widget build(BuildContext context) => GlassScaffold(
        body: SafeArea(
          child: Column(
            children: [
              const _AssistantHeader(),
              if (disclosureAccepted && !headerTourSeen)
                _HeaderTourBanner(onDismiss: _dismissHeaderTour),
              Expanded(
                child: Obx(() {
                  final messages =
                      orchestrator.messages.toList(growable: false);
                  if (messages.isEmpty) {
                    return AssistantEmptyConversation(
                        active: orchestrator.sending.value,
                        snapshot: todaySnapshot,
                        onSelected: _send);
                  }
                  final visible = <List<ChatMessage>>[];
                  for (final message in messages) {
                    if (message.status == ChatMessageStatus.error &&
                        visible.isNotEmpty &&
                        visible.last.last.status == ChatMessageStatus.error &&
                        visible.last.last.text == message.text) {
                      continue;
                    }
                    if (message.kind == ChatMessageKind.working &&
                        visible.isNotEmpty &&
                        visible.last.last.kind == ChatMessageKind.working) {
                      visible.last.add(message);
                    } else {
                      visible.add([message]);
                    }
                  }
                  return ListView.builder(
                    controller: scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    itemCount: visible.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      // Each bubble arrives with a short fade-lift; recycling
                      // replays are harmless because the entrance is 260ms and
                      // settle-based, not a looping animation.
                      child: _BubbleEntrance(
                        child: visible[index].first.kind ==
                                ChatMessageKind.working
                            ? AssistantToolActivity(messages: visible[index])
                            : AssistantMessageCard(
                                message: visible[index].first,
                                failure: index == visible.length - 1
                                    ? orchestrator.lastFailure.value
                                    : null,
                                onRetry: orchestrator.retryLast,
                              ),
                      ),
                    ),
                  );
                }),
              ),
              if (!disclosureAccepted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: _DisclosureCard(onAccept: _acceptDisclosure),
                )
              else ...[
                _SuggestionRail(onSelected: _send),
                _Composer(
                  controller: composer,
                  sending: orchestrator.sending,
                  onSend: _send,
                ),
              ],
            ],
          ),
        ),
      );
}
