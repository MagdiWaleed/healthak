/// What a write tool call is asking to do. Two kinds (`restoreEntry`,
/// `deleteMeal`) never come from a model tool call directly -- they only ever
/// appear as the inverse of another proposal, built by the registry so undo
/// can reuse the exact same execute path as a normal confirm.
enum ProposalKind {
  logFood,
  logMeal,
  swapMeal,
  updateGrams,
  removeEntry,
  createMeal,
  logCustomComponent,
  restoreEntry,
  deleteMeal,
}

/// A pending write, parked in the conversation until the user taps تأكيد.
///
/// Nothing about a [Proposal] has touched a repository yet -- [execArgs]
/// already carries fully-resolved, validated data (real `FoodItem`s,
/// real `DayEntry` snapshots), never raw model-supplied ids or macros, so
/// confirming it later cannot re-introduce a hallucinated value.
class Proposal {
  final String id;
  final String toolCallId;
  final ProposalKind kind;

  /// Chat-bubble headline, e.g. «هسجّل صدر دجاج (150 جم) في الغداء».
  final String titleAr;

  /// Structured fields the card renders (old/new names, deltas, badges).
  /// JSON-safe-ish but never round-tripped -- read directly by the widget.
  final Map<String, dynamic> card;

  /// What gets told back to the model as this tool call's result. Never
  /// includes a macro number the model didn't already have -- only enough to
  /// let it write one calm follow-up line.
  final Map<String, dynamic> modelSummary;

  /// Kind-specific resolved payload. Registry-internal; the UI never reads
  /// this, only [card].
  final Object execArgs;

  const Proposal({
    required this.id,
    required this.toolCallId,
    required this.kind,
    required this.titleAr,
    required this.card,
    required this.modelSummary,
    required this.execArgs,
  });
}

/// What executing a confirmed (or undone) [Proposal] produced.
class AgentReceipt {
  final String id;
  final ProposalKind kind;

  /// Chat-bubble line, e.g. «سجّلت صدر دجاج (150 جم) في الغداء».
  final String summaryAr;

  /// Ready-to-confirm proposals that would undo this receipt, applied in
  /// order. Empty when the action cannot be undone (e.g. deleting a meal
  /// from the library after which nothing has a snapshot to restore from).
  final List<Proposal> inverse;

  final DateTime executedAt;

  const AgentReceipt({
    required this.id,
    required this.kind,
    required this.summaryAr,
    required this.inverse,
    required this.executedAt,
  });

  bool get isUndoable => inverse.isNotEmpty;
}

/// The underlying day/entry changed since the proposal was built (someone
/// edited it elsewhere, or a previous confirm/undo already touched it).
/// Confirming against stale state is refused rather than silently
/// overwriting whatever changed.
class AgentProposalStaleException implements Exception {
  const AgentProposalStaleException();

  static const messageAr = 'المعطيات اتغيّرت، أعمل اقتراح جديد.';

  @override
  String toString() => messageAr;
}
