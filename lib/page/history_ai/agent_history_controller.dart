import 'dart:async';

import 'package:get/get.dart';

import '../../service/agent/agent_action_log.dart';
import '../../service/agent/agent_tool_registry.dart';

enum AgentHistoryFilter { all, add, edit, remove, swap }

/// Drives «سجل المساعد» -- Phase 5C. Reads the persisted, cross-session
/// audit log and replays a row's stored inverse through the registry on
/// «تراجع», exactly like the inline chat receipt chip does, just from
/// serialized state instead of a live `Proposal` object.
class AgentHistoryController extends GetxController {
  final AgentActionLog _log;
  final AgentToolRegistry _tools;

  AgentHistoryController({
    required AgentActionLog log,
    required AgentToolRegistry tools,
  })  : _log = log,
        _tools = tools;

  final entries = <AgentActionLogEntry>[].obs;
  final loading = true.obs;
  final filter = AgentHistoryFilter.all.obs;

  /// The one entry currently mid-undo, so its row can show a spinner and
  /// every row's تراجع can be disabled while it's in flight.
  final undoingId = RxnString();
  final lastError = RxnString();

  @override
  void onInit() {
    super.onInit();
    unawaited(_load());
  }

  Future<void> _load() async {
    loading.value = true;
    try {
      entries.assignAll(await _log.list());
    } finally {
      loading.value = false;
    }
  }

  List<AgentActionLogEntry> get filtered {
    final active = filter.value;
    if (active == AgentHistoryFilter.all) return entries;
    return entries.where((entry) {
      final category = entry.category;
      return switch (active) {
        AgentHistoryFilter.all => true,
        AgentHistoryFilter.add => category == AgentActionCategory.add,
        AgentHistoryFilter.edit => category == AgentActionCategory.edit,
        AgentHistoryFilter.remove => category == AgentActionCategory.remove,
        AgentHistoryFilter.swap => category == AgentActionCategory.swap,
      };
    }).toList(growable: false);
  }

  Future<void> undo(String entryId) async {
    if (undoingId.value != null) return;
    final index = entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;
    final entry = entries[index];
    if (!entry.isUndoable) return;

    undoingId.value = entryId;
    lastError.value = null;
    try {
      final proposals = [
        for (final json in entry.inverseChain)
          if (_tools.deserializeProposalForLog(json) case final proposal?) proposal,
      ];
      if (proposals.isEmpty) {
        lastError.value = 'تعذّر تنفيذ التراجع. حاول مرة أخرى.';
        return;
      }
      for (final proposal in proposals) {
        final receipt = await _tools.confirm(proposal);
        await _log.record(AgentActionLogEntry(
          id: receipt.id,
          timestamp: receipt.executedAt,
          kind: receipt.kind,
          humanSummary: receipt.summaryAr,
          inverseChain: [
            for (final inverse in receipt.inverse)
              if (_tools.serializeProposalForLog(inverse) case final json?) json,
          ],
        ));
      }
      await _log.markUndone(entryId, DateTime.now());
      await _load();
    } on Object {
      // Stale underlying state (day changed since) or any other failure --
      // a polite refusal, not a crash. Reload so the list reflects reality.
      lastError.value = 'تعذّر التراجع، قد تكون البيانات تغيّرت. حاول مرة أخرى.';
      await _load();
    } finally {
      undoingId.value = null;
    }
  }
}
