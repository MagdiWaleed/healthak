/// The user-selectable xAI models for the assistant.
///
/// Kept small and edited here. The proxy (`functions/index.js`) enforces the
/// same allowlist server-side so a modified client cannot request an arbitrary
/// (or more expensive) model.
class AgentModel {
  final String id;
  final String label;

  /// `reasoning_effort` value to send, or null to omit the field. Grok "mini"
  /// models accept `low`/`high`; the fast non-reasoning and full Grok models
  /// reject the field, so it must not be sent for them.
  final String? reasoningEffort;

  /// Short note shown under the label in the picker.
  final String noteAr;

  const AgentModel({
    required this.id,
    required this.label,
    required this.noteAr,
    this.reasoningEffort,
  });
}

abstract final class AgentModels {
  /// xAI's cheapest model — the default.
  static const grok3Mini = AgentModel(
    id: 'grok-3-mini',
    label: 'Grok 3 Mini',
    noteAr: 'الأرخص · مناسب لأغلب الأسئلة',
    reasoningEffort: 'low',
  );

  static const grok4FastNonReasoning = AgentModel(
    id: 'grok-4-fast-non-reasoning',
    label: 'Grok 4 Fast',
    noteAr: 'أسرع · إجابات مباشرة',
  );

  static const grok4FastReasoning = AgentModel(
    id: 'grok-4-fast-reasoning',
    label: 'Grok 4 Fast · تفكير',
    noteAr: 'استدلال أعمق بتكلفة أعلى قليلًا',
  );

  static const grok4 = AgentModel(
    id: 'grok-4',
    label: 'Grok 4',
    noteAr: 'الأقوى · الأغلى',
  );

  static const all = <AgentModel>[
    grok3Mini,
    grok4FastNonReasoning,
    grok4FastReasoning,
    grok4,
  ];

  static const fallbackId = 'grok-3-mini';

  static AgentModel byId(String? id) => all.firstWhere(
        (model) => model.id == id,
        orElse: () => grok3Mini,
      );

  static bool isKnown(String? id) => all.any((model) => model.id == id);
}
