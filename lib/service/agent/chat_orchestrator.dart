import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'agent_action_log.dart';
import 'agent_conversation_store.dart';
import 'agent_models.dart';
import 'agent_proposal.dart';
import 'agent_tool_registry.dart';
import 'ai_client.dart';
import 'chat_session.dart';
import 'chat_title_generator.dart';

const int kMaxAgentToolCallsPerTurn = 6;

class ChatOrchestrator extends GetxController {
  final AiClient _client;
  final AgentToolRegistry _tools;
  final AgentConversationStore? _conversationStore;
  final ChatTitleGenerator? _titleGenerator;
  final AgentActionLog? _actionLog;
  final Uuid _uuid;

  /// Returns the xAI model id to use for the next turn, re-read each turn so a
  /// change in the model picker takes effect immediately.
  final String Function()? _resolveModel;

  ChatOrchestrator({
    required AiClient client,
    required AgentToolRegistry tools,
    AgentConversationStore? conversationStore,
    ChatTitleGenerator? titleGenerator,
    AgentActionLog? actionLog,
    String Function()? resolveModel,
    Uuid uuid = const Uuid(),
  })  : _client = client,
        _tools = tools,
        _conversationStore = conversationStore,
        _titleGenerator = titleGenerator,
        _actionLog = actionLog,
        _resolveModel = resolveModel,
        _uuid = uuid;

  final messages = <ChatMessage>[].obs;
  final sending = false.obs;
  final lastFailure = Rxn<AgentFailureKind>();
  final lastTurnCostUsd = RxnDouble();

  /// Every conversation thread, newest first. Populated on init and kept in
  /// sync as sessions are created, titled, switched to, or deleted.
  final sessions = <ChatSession>[].obs;
  final currentSessionId = Rxn<String>();

  final List<Map<String, dynamic>> _apiMessages = [];
  Future<void> _restoreFuture = Future.value();

  @override
  void onInit() {
    super.onInit();
    _restoreFuture = _initSessions();
  }

  /// Starts a new, empty thread. Nothing is persisted until the first
  /// message is actually sent in it -- switching away or closing the app
  /// before that leaves no empty session behind.
  Future<void> startNewSession() async {
    await _restoreFuture;
    if (sending.value) return;
    currentSessionId.value = _uuid.v4();
    messages.clear();
    _apiMessages.clear();
    lastFailure.value = null;
    lastTurnCostUsd.value = null;
  }

  /// Switches to an existing thread, restoring its messages and rebuilding
  /// the model-facing context the same way app restart does.
  Future<void> openSession(String id) async {
    await _restoreFuture;
    if (sending.value || currentSessionId.value == id) return;
    await _loadSession(id);
  }

  Future<void> deleteSession(String id) async {
    await _restoreFuture;
    await _conversationStore?.deleteSession(id);
    sessions.removeWhere((session) => session.id == id);
    if (currentSessionId.value == id) {
      if (sessions.isNotEmpty) {
        await _loadSession(sessions.first.id);
      } else {
        await startNewSession();
      }
    }
  }

  Future<void> send(String rawText) async {
    await _restoreFuture;
    final text = rawText.trim();
    if (text.isEmpty || sending.value) return;
    currentSessionId.value ??= _uuid.v4();
    final isFirstMessageInSession =
        messages.every((message) => message.kind != ChatMessageKind.user);

    final turnId = _uuid.v4();
    messages.add(ChatMessage(
      id: _uuid.v4(),
      kind: ChatMessageKind.user,
      text: text,
      createdAt: DateTime.now(),
    ));
    _apiMessages.add({'role': 'user', 'content': text});
    sending.value = true;
    lastFailure.value = null;
    lastTurnCostUsd.value = null;

    try {
      var callsUsed = 0;
      var toolsEnabled = true;
      final model = _resolveModel?.call();
      // Precalled once per user message (not per tool-call round trip
      // within it) -- fresh enough to reflect anything confirmed in an
      // earlier turn, without re-fetching on every loop iteration. Never
      // blocks the turn: a failure here just means no precall this time,
      // the model still has search_foods/get_meals as before.
      String? knownCatalog;
      try {
        knownCatalog = await _tools.buildKnownCatalogContext();
      } on Object {
        knownCatalog = null;
      }
      while (true) {
        final assistantId = _uuid.v4();
        messages.add(ChatMessage(
          id: assistantId,
          kind: ChatMessageKind.assistant,
          status: ChatMessageStatus.streaming,
          text: '',
          createdAt: DateTime.now(),
        ));

        final calls = <AgentToolCall>[];
        final textBuffer = StringBuffer();
        await for (final chunk in _client.agentTurn(
          turnId: turnId,
          messages: List.unmodifiable(_apiMessages),
          tools: toolsEnabled ? _tools.definitions : const [],
          model: model,
          knownCatalog: knownCatalog,
        )) {
          switch (chunk) {
            case AgentTextDelta(:final text):
              textBuffer.write(text);
              _replaceMessage(
                assistantId,
                (message) => message.copyWith(text: textBuffer.toString()),
              );
            case AgentToolCallChunk(:final call):
              calls.add(call);
            case AgentUsageChunk(:final costUsd):
              if (costUsd != null) {
                lastTurnCostUsd.value = (lastTurnCostUsd.value ?? 0) + costUsd;
              }
            case AgentDoneChunk():
              break;
          }
        }

        final assistantText = textBuffer.toString().trim();
        if (assistantText.isEmpty && calls.isNotEmpty) {
          messages.removeWhere((message) => message.id == assistantId);
        } else {
          _replaceMessage(
            assistantId,
            (message) => message.copyWith(
              text: assistantText,
              status: ChatMessageStatus.complete,
            ),
          );
        }

        if (calls.isEmpty) {
          if (assistantText.isNotEmpty) {
            _apiMessages.add({'role': 'assistant', 'content': assistantText});
          }
          _trimApiContext();
          break;
        }

        callsUsed += calls.length;
        if (callsUsed > kMaxAgentToolCallsPerTurn) {
          toolsEnabled = false;
          _apiMessages.add({
            'role': 'system',
            'content':
                'توقّف عن استدعاء الأدوات وأجب الآن بما توفر لديك، واذكر بوضوح ما لم تستطع التحقق منه.',
          });
          continue;
        }

        _apiMessages.add({
          'role': 'assistant',
          if (assistantText.isNotEmpty) 'content': assistantText,
          'tool_calls': [
            for (final call in calls)
              {
                'id': call.id,
                'type': 'function',
                'function': {
                  'name': call.name,
                  'arguments': jsonEncode(call.arguments),
                },
              },
          ],
        });

        var proposedThisBatch = false;
        for (final call in calls) {
          final workingId = _uuid.v4();
          messages.add(ChatMessage(
            id: workingId,
            kind: ChatMessageKind.working,
            status: ChatMessageStatus.streaming,
            text: _workingLabel(call.name),
            toolName: call.name,
            createdAt: DateTime.now(),
          ));
          final result = await _tools.run(call);
          _replaceMessage(
            workingId,
            (message) => message.copyWith(
              status: result.isError
                  ? ChatMessageStatus.error
                  : ChatMessageStatus.complete,
              text: result.isError
                  ? result.data['message_ar'] as String? ??
                      'تعذّر قراءة البيانات.'
                  : _completeLabel(call.name),
            ),
          );
          _apiMessages.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'content': jsonEncode(result.data),
          });

          final proposal = result.proposal;
          if (proposal != null) {
            proposedThisBatch = true;
            _supersedePendingProposals();
            messages.add(ChatMessage(
              id: _uuid.v4(),
              kind: ChatMessageKind.proposal,
              status: ChatMessageStatus.pendingConfirm,
              text: proposal.titleAr,
              proposal: proposal,
              createdAt: DateTime.now(),
            ));
          }
        }

        // One in-flight proposal at a time: once this batch produced one,
        // let the model say one short line and stop -- it must not chain
        // straight into a second proposal before the user has acted on the
        // first.
        if (proposedThisBatch) toolsEnabled = false;
      }
    } on AgentException catch (error) {
      lastFailure.value = error.kind;
      ChatMessage? streaming;
      for (final message in messages.reversed) {
        if (message.kind == ChatMessageKind.assistant &&
            message.status == ChatMessageStatus.streaming) {
          streaming = message;
          break;
        }
      }
      if (streaming == null) {
        messages.add(ChatMessage(
          id: _uuid.v4(),
          kind: ChatMessageKind.notice,
          status: ChatMessageStatus.error,
          text: error.message,
          createdAt: DateTime.now(),
        ));
      } else {
        _replaceMessage(
          streaming.id,
          (message) => message.copyWith(
            status: ChatMessageStatus.error,
            text: message.text.isEmpty ? error.message : message.text,
          ),
        );
      }
    } finally {
      sending.value = false;
      await _saveConversation();
      if (isFirstMessageInSession) _maybeGenerateTitle(text);
    }
  }

  /// Executes a pending proposal's write and turns its card into a receipt
  /// with an undo chip. No-ops if the card was already resolved (double-tap
  /// guard) or the message id is gone.
  Future<void> confirmProposal(String proposalMessageId) async {
    final index =
        messages.indexWhere((message) => message.id == proposalMessageId);
    if (index == -1) return;
    final message = messages[index];
    final proposal = message.proposal;
    if (proposal == null || message.status != ChatMessageStatus.pendingConfirm) {
      return;
    }
    messages[index] = message.copyWith(status: ChatMessageStatus.complete);
    try {
      final receipt = await _tools.confirm(proposal);
      messages.add(ChatMessage(
        id: _uuid.v4(),
        kind: ChatMessageKind.receipt,
        text: receipt.summaryAr,
        receipt: receipt,
        createdAt: DateTime.now(),
      ));
      _apiMessages.add({
        'role': 'system',
        'content': 'نُفّذ الاقتراح: ${receipt.summaryAr}',
      });
      await _recordAction(receipt);
    } catch (error) {
      messages[index] = message.copyWith(
        status: ChatMessageStatus.error,
        text: error is AgentProposalStaleException
            ? AgentProposalStaleException.messageAr
            : 'تعذّر تنفيذ الاقتراح. حاول مرة أخرى.',
      );
    }
    await _saveConversation();
  }

  /// Dismisses a pending proposal without writing anything.
  Future<void> cancelProposal(String proposalMessageId) async {
    final index =
        messages.indexWhere((message) => message.id == proposalMessageId);
    if (index == -1) return;
    final message = messages[index];
    if (message.status != ChatMessageStatus.pendingConfirm) return;
    messages[index] = message.copyWith(status: ChatMessageStatus.cancelled);
    await _saveConversation();
  }

  /// Reverses a confirmed action. The 10-minute window is enforced by the
  /// undo chip's own visibility (`_ReceiptCard` in the assistant tab), not
  /// here -- the registry itself has no notion of a deadline.
  Future<void> undoReceipt(String receiptMessageId) async {
    final index =
        messages.indexWhere((message) => message.id == receiptMessageId);
    if (index == -1) return;
    final message = messages[index];
    final receipt = message.receipt;
    if (receipt == null || message.status == ChatMessageStatus.undone) return;
    try {
      final steps = await _tools.undo(receipt);
      messages[index] = message.copyWith(
        status: ChatMessageStatus.undone,
        text: message.text,
      );
      // The undo is itself a logged, undoable action (each inverse step
      // gets its own audit row); the original row it reverses is marked
      // undone, never rewritten.
      for (final step in steps) {
        await _recordAction(step);
      }
      await _actionLog?.markUndone(receipt.id, DateTime.now());
    } catch (_) {
      // Leave the receipt as-is; the chip stays tappable so the user can
      // retry rather than losing the affordance on one transient failure.
    }
    await _saveConversation();
  }

  /// Appends one confirmed write (a direct confirm or one step of an undo)
  /// to the persisted, cross-session audit log -- Phase 5C "سجل المساعد".
  /// Best-effort: a failure here never blocks the chat turn that produced it.
  Future<void> _recordAction(AgentReceipt receipt) async {
    final log = _actionLog;
    if (log == null) return;
    final inverseChain = [
      for (final proposal in receipt.inverse)
        if (_tools.serializeProposalForLog(proposal) case final json?) json,
    ];
    try {
      await log.record(AgentActionLogEntry(
        id: receipt.id,
        timestamp: receipt.executedAt,
        kind: receipt.kind,
        humanSummary: receipt.summaryAr,
        inverseChain: inverseChain,
      ));
    } on Object {
      // The chat receipt already shows the result; a logging failure just
      // means this write won't appear in the persisted audit screen.
    }
  }

  void _supersedePendingProposals() {
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.kind == ChatMessageKind.proposal &&
          message.status == ChatMessageStatus.pendingConfirm) {
        messages[i] = message.copyWith(status: ChatMessageStatus.cancelled);
      }
    }
  }

  Future<void> retryLast() async {
    for (final message in messages.reversed) {
      if (message.kind == ChatMessageKind.user) {
        await send(message.text);
        return;
      }
    }
  }

  /// Loads the session list and opens the most recent thread, if any.
  Future<void> _initSessions() async {
    final store = _conversationStore;
    if (store == null) return;
    try {
      final loaded = await store.listSessions();
      sessions.assignAll(loaded);
      if (loaded.isNotEmpty) await _loadSession(loaded.first.id);
    } on Object {
      // Corrupt or unavailable local history must never block a new chat --
      // the user just starts fresh, same as a first-ever launch.
    }
  }

  Future<void> _loadSession(String id) async {
    currentSessionId.value = id;
    messages.clear();
    _apiMessages.clear();
    final store = _conversationStore;
    if (store == null) return;
    try {
      final restored = await store.loadMessages(id);
      messages.assignAll(restored);
      final conversational = restored
          .where((message) =>
              message.kind == ChatMessageKind.user ||
              (message.kind == ChatMessageKind.assistant &&
                  message.status == ChatMessageStatus.complete))
          .toList(growable: false);
      final start = conversational.length > 40 ? conversational.length - 40 : 0;
      for (final message in conversational.skip(start)) {
        _apiMessages.add({
          'role': message.kind == ChatMessageKind.user ? 'user' : 'assistant',
          'content': message.text,
        });
      }
    } on Object {
      // Leave this session empty rather than block switching to it.
    }
  }

  Future<void> _saveConversation() async {
    final id = currentSessionId.value;
    final store = _conversationStore;
    if (id == null || store == null) return;
    try {
      await store.saveMessages(id, messages);
      final now = DateTime.now();
      final existing = sessions.firstWhereOrNull((s) => s.id == id);
      final session = existing?.copyWith(updatedAt: now) ??
          ChatSession(id: id, createdAt: now, updatedAt: now);
      await store.upsertSession(session);
      sessions.removeWhere((s) => s.id == id);
      sessions.insert(0, session);
    } on Object {
      // The current turn remains usable even when local persistence fails.
    }
  }

  /// Fires once, in the background, right after a session's first exchange
  /// completes -- never blocks sending or shows an error of its own. Falls
  /// back to a plain truncation of the first message if generation is
  /// unavailable or fails (offline, no key, bad response).
  void _maybeGenerateTitle(String firstUserText) {
    final id = currentSessionId.value;
    if (id == null) return;
    unawaited(() async {
      String? title;
      final generator = _titleGenerator;
      if (generator != null) {
        try {
          title = await generator.generateTitle(firstUserText);
        } on Object {
          title = null;
        }
      }
      title ??= _fallbackTitle(firstUserText);

      final index = sessions.indexWhere((s) => s.id == id);
      if (index == -1) return;
      final updated = sessions[index].copyWith(title: title);
      sessions[index] = updated;
      try {
        await _conversationStore?.upsertSession(updated);
      } on Object {
        // The title still shows for this session; it just won't survive a
        // restart if this particular write failed.
      }
    }());
  }

  static String _fallbackTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'محادثة جديدة';
    return trimmed.runes.length > 40
        ? '${String.fromCharCodes(trimmed.runes.take(40))}…'
        : trimmed;
  }

  void _trimApiContext() {
    if (_apiMessages.length <= 60) return;
    _apiMessages.removeRange(0, _apiMessages.length - 60);
    while (_apiMessages.isNotEmpty && _apiMessages.first['role'] != 'user') {
      _apiMessages.removeAt(0);
    }
  }

  void _replaceMessage(
    String id,
    ChatMessage Function(ChatMessage current) update,
  ) {
    final index = messages.indexWhere((message) => message.id == id);
    if (index != -1) messages[index] = update(messages[index]);
  }

  static String _workingLabel(String tool) => switch (tool) {
        'get_today' => 'أقرأ سجل يومك…',
        'get_history_range' => 'أراجع أيامك الأخيرة…',
        'get_profile' => 'أراجع هدفك وأرقامك…',
        'get_meals' => 'أفتح مكتبة وجباتك…',
        'search_foods' => 'أبحث في المكوّنات المسجّلة…',
        'get_remaining_targets' => 'أحسب المتبقي من هدفك…',
        'search_food_online' => 'أبحث في الإنترنت…',
        'propose_log_food' ||
        'propose_log_meal' ||
        'propose_swap_meal' ||
        'propose_update_grams' ||
        'propose_remove_entry' ||
        'propose_create_meal' ||
        'propose_log_custom_component' =>
          'أجهّز اقتراحًا…',
        _ => 'أراجع بياناتك…',
      };

  static String _completeLabel(String tool) => switch (tool) {
        'get_today' => 'قرأت سجل اليوم',
        'get_history_range' => 'راجعت الأيام المطلوبة',
        'get_profile' => 'راجعت هدفك',
        'get_meals' => 'راجعت مكتبة وجباتك',
        'search_foods' => 'وجدت نتائج من الكتالوج',
        'get_remaining_targets' => 'حسبت المتبقي اليوم',
        'search_food_online' => 'وجدت نتائج من الإنترنت',
        'propose_log_food' ||
        'propose_log_meal' ||
        'propose_swap_meal' ||
        'propose_update_grams' ||
        'propose_remove_entry' ||
        'propose_create_meal' ||
        'propose_log_custom_component' =>
          'الاقتراح جاهز، بانتظار تأكيدك',
        _ => 'اكتملت قراءة البيانات',
      };
}
