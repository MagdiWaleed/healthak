import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'agent_proposal.dart';

/// Broad category a `تراجع` filter chip groups by. Derived from
/// [AgentActionLogEntry.kind], never stored on its own.
enum AgentActionCategory { add, edit, remove, swap }

extension AgentActionCategoryOf on ProposalKind {
  AgentActionCategory? get logCategory => switch (this) {
        ProposalKind.logFood ||
        ProposalKind.logMeal ||
        ProposalKind.createMeal ||
        ProposalKind.logCustomComponent ||
        ProposalKind.restoreEntry =>
          AgentActionCategory.add,
        ProposalKind.updateGrams => AgentActionCategory.edit,
        ProposalKind.removeEntry || ProposalKind.deleteMeal =>
          AgentActionCategory.remove,
        ProposalKind.swapMeal => AgentActionCategory.swap,
      };
}

/// One row in the persisted, cross-session audit trail of every write the
/// agent has actually executed -- Phase 5C "سجل المساعد". Append-only: an
/// undone entry is marked, never deleted or rewritten.
class AgentActionLogEntry {
  final String id;
  final DateTime timestamp;
  final ProposalKind kind;
  final String humanSummary;
  final DateTime? undoneAt;

  /// The inverse chain, already JSON-safe
  /// (`AgentToolRegistry.serializeProposalForLog`). Empty when the action
  /// was never undoable in the first place (e.g. deleting a meal).
  final List<Map<String, dynamic>> inverseChain;

  const AgentActionLogEntry({
    required this.id,
    required this.timestamp,
    required this.kind,
    required this.humanSummary,
    required this.inverseChain,
    this.undoneAt,
  });

  bool get isUndone => undoneAt != null;
  bool get isUndoable => inverseChain.isNotEmpty && !isUndone;
  AgentActionCategory? get category => kind.logCategory;

  AgentActionLogEntry markedUndone(DateTime at) => AgentActionLogEntry(
        id: id,
        timestamp: timestamp,
        kind: kind,
        humanSummary: humanSummary,
        inverseChain: inverseChain,
        undoneAt: at,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'kind': kind.name,
        'humanSummary': humanSummary,
        'inverseChain': inverseChain,
        'undoneAt': undoneAt?.toIso8601String(),
      };

  static AgentActionLogEntry? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '');
    final kindName = json['kind'];
    final summary = json['humanSummary'];
    if (id is! String || timestamp == null || kindName is! String || summary is! String) {
      return null;
    }
    final kind = ProposalKind.values.where((k) => k.name == kindName).firstOrNull;
    if (kind == null) return null;
    final rawChain = json['inverseChain'];
    return AgentActionLogEntry(
      id: id,
      timestamp: timestamp,
      kind: kind,
      humanSummary: summary,
      inverseChain: rawChain is List
          ? [for (final row in rawChain) (row as Map).cast<String, dynamic>()]
          : const [],
      undoneAt: json['undoneAt'] != null
          ? DateTime.tryParse(json['undoneAt'] as String)
          : null,
    );
  }
}

abstract interface class AgentActionLog {
  /// Newest first, pruned to the retention window.
  Future<List<AgentActionLogEntry>> list();
  Future<void> record(AgentActionLogEntry entry);
  Future<void> markUndone(String entryId, DateTime at);
}

/// Device-only, 30-day retention, v1. Firestore `users/{uid}/agentActions`
/// is the flagged sync upgrade from `04_action_history.md` -- not built now.
class SharedPrefsAgentActionLog implements AgentActionLog {
  static const _key = 'assistant.actionLog.v1';
  static const _retentionDays = 30;

  final SharedPreferences? _preferences;
  final DateTime Function() _now;

  SharedPrefsAgentActionLog({
    SharedPreferences? preferences,
    DateTime Function()? now,
  })  : _preferences = preferences,
        _now = now ?? DateTime.now;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  @override
  Future<List<AgentActionLogEntry>> list() async {
    final prefs = await _prefs;
    final entries = _prune(_decode(prefs.getString(_key)));
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  @override
  Future<void> record(AgentActionLogEntry entry) async {
    final prefs = await _prefs;
    final entries = _prune(_decode(prefs.getString(_key)))..add(entry);
    await _write(prefs, entries);
  }

  @override
  Future<void> markUndone(String entryId, DateTime at) async {
    final prefs = await _prefs;
    final entries = _prune(_decode(prefs.getString(_key)));
    final index = entries.indexWhere((e) => e.id == entryId);
    if (index != -1) entries[index] = entries[index].markedUndone(at);
    await _write(prefs, entries);
  }

  List<AgentActionLogEntry> _prune(List<AgentActionLogEntry> entries) {
    final oldest = _now().subtract(const Duration(days: _retentionDays));
    return entries.where((e) => e.timestamp.isAfter(oldest)).toList();
  }

  List<AgentActionLogEntry> _decode(String? raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final row in decoded)
          if (AgentActionLogEntry.fromJson((row as Map).cast<String, dynamic>())
              case final entry?)
            entry,
      ];
    } on Object {
      return [];
    }
  }

  Future<void> _write(
    SharedPreferences prefs,
    List<AgentActionLogEntry> entries,
  ) =>
      prefs.setString(
        _key,
        jsonEncode([for (final e in entries) e.toJson()]),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
