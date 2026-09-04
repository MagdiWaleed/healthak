import 'package:diet_app2/service/agent/agent_action_log.dart';
import 'package:diet_app2/service/agent/agent_proposal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('records an entry and lists it newest-first', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final log = SharedPrefsAgentActionLog(preferences: prefs);

    await log.record(AgentActionLogEntry(
      id: 'a1',
      timestamp: DateTime(2026, 9, 4, 10),
      kind: ProposalKind.logFood,
      humanSummary: 'سجّلت صدر دجاج',
      inverseChain: const [
        {'kind': 'removeEntry'},
      ],
    ));
    await log.record(AgentActionLogEntry(
      id: 'a2',
      timestamp: DateTime(2026, 9, 4, 11),
      kind: ProposalKind.removeEntry,
      humanSummary: 'حذفت الأرز',
      inverseChain: const [],
    ));

    final entries = await log.list();
    expect(entries.map((e) => e.id), ['a2', 'a1']);
    expect(entries.last.isUndoable, isTrue);
    expect(entries.first.isUndoable, isFalse);
  });

  test('markUndone stamps the entry and it stays undoable=false', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final log = SharedPrefsAgentActionLog(preferences: prefs);

    await log.record(AgentActionLogEntry(
      id: 'a1',
      timestamp: DateTime(2026, 9, 4),
      kind: ProposalKind.logFood,
      humanSummary: 'سجّلت صدر دجاج',
      inverseChain: const [
        {'kind': 'removeEntry'},
      ],
    ));
    await log.markUndone('a1', DateTime(2026, 9, 4, 1));

    final entry = (await log.list()).single;
    expect(entry.isUndone, isTrue);
    expect(entry.isUndoable, isFalse);
    expect(entry.undoneAt, DateTime(2026, 9, 4, 1));
  });

  test('prunes entries older than 30 days', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 9, 4);
    final log = SharedPrefsAgentActionLog(preferences: prefs, now: () => now);

    await log.record(AgentActionLogEntry(
      id: 'old',
      timestamp: now.subtract(const Duration(days: 31)),
      kind: ProposalKind.logFood,
      humanSummary: 'قديم',
      inverseChain: const [],
    ));
    await log.record(AgentActionLogEntry(
      id: 'kept',
      timestamp: now.subtract(const Duration(days: 1)),
      kind: ProposalKind.logFood,
      humanSummary: 'حديث',
      inverseChain: const [],
    ));

    final entries = await log.list();
    expect(entries.map((e) => e.id), ['kept']);
  });

  test('every ProposalKind maps to a filter category except the internal-only ones',
      () {
    expect(ProposalKind.logFood.logCategory, AgentActionCategory.add);
    expect(ProposalKind.logMeal.logCategory, AgentActionCategory.add);
    expect(ProposalKind.createMeal.logCategory, AgentActionCategory.add);
    expect(ProposalKind.logCustomComponent.logCategory, AgentActionCategory.add);
    expect(ProposalKind.restoreEntry.logCategory, AgentActionCategory.add);
    expect(ProposalKind.updateGrams.logCategory, AgentActionCategory.edit);
    expect(ProposalKind.removeEntry.logCategory, AgentActionCategory.remove);
    expect(ProposalKind.deleteMeal.logCategory, AgentActionCategory.remove);
    expect(ProposalKind.swapMeal.logCategory, AgentActionCategory.swap);
  });
}
