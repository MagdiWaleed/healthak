part of '../assistant_tab.dart';

class _ProposalCard extends StatelessWidget {
  final ChatMessage message;
  const _ProposalCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final proposal = message.proposal;
    if (proposal == null) return const SizedBox.shrink();
    final pending = message.status == ChatMessageStatus.pendingConfirm;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        // The decision point of the whole agent journey: while a proposal
        // waits, the card breathes a violet glow so "the app is asking you
        // something" reads from across the room. Resolved proposals render
        // flat. `BoxShadow` only -- no blur filter, budget untouched.
        child: AppMotion.pop(GlassCard(
          elevation: GlassElevation.panel,
          highlighted: pending,
          tint: pending ? AppPalette.emerald : null,
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: pending ? AppPalette.violet : AppPalette.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      proposal.titleAr,
                      style: TextStyle(
                        color: pending ? AppPalette.text : AppPalette.muted,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              ..._ProposalDetails.rowsFor(proposal),
              if (pending) ...[
                const SizedBox(height: 8),
                const Text(AppStrings.assistantConfirmNote,
                    style: TextStyle(fontSize: 11, color: AppPalette.muted)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ProposalButton(
                        label: AppStrings.assistantConfirm,
                        filled: true,
                        onTap: () => Get.find<ChatOrchestrator>()
                            .confirmProposal(message.id),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProposalButton(
                        label: AppStrings.assistantCancel,
                        filled: false,
                        onTap: () => Get.find<ChatOrchestrator>()
                            .cancelProposal(message.id),
                      ),
                    ),
                  ],
                ),
                if (proposal.kind == ProposalKind.logFood) ...[
                  const SizedBox(height: 8),
                  _ProposalButton(
                    label: AppStrings.assistantEdit,
                    filled: false,
                    onTap: () => _FoodProposalEditSheet.show(context, message),
                  ),
                ],
              ] else if (message.status == ChatMessageStatus.cancelled) ...[
                const SizedBox(height: 6),
                const Text(
                  AppStrings.assistantCancelled,
                  style: TextStyle(color: AppPalette.muted, fontSize: 11),
                ),
              ],
            ],
          ),
        )),
      ),
    );
  }
}

class _FoodProposalEditSheet extends StatefulWidget {
  final ChatMessage message;
  const _FoodProposalEditSheet(this.message);

  static Future<void> show(BuildContext context, ChatMessage message) =>
      GlassSheet.show<void>(
        context,
        builder: (_) => _FoodProposalEditSheet(message),
      );

  @override
  State<_FoodProposalEditSheet> createState() => _FoodProposalEditSheetState();
}

class _FoodProposalEditSheetState extends State<_FoodProposalEditSheet> {
  late final TextEditingController grams = TextEditingController(
    text: (widget.message.proposal?.card['grams'] as num? ?? 100).toString(),
  );
  late MealSlot slot = MealSlot.values.firstWhere(
    (value) => value.labelAr == widget.message.proposal?.card['slot_ar'],
    orElse: () => MealSlot.snack,
  );
  bool saving = false;
  String? error;

  double? get amount => parseNutritionAmount(grams.text);
  bool get valid => isPortionGrams(amount);

  @override
  void dispose() {
    grams.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!valid || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await Get.find<ChatOrchestrator>().reviseFoodProposal(
        widget.message.id,
        grams: amount!,
        slot: slot,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = AppStrings.assistantEditFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => GlassSheet(
        title: AppStrings.assistantEditFoodTitle,
        topInset: 100,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.message.proposal?.card['name']?.toString() ?? ''),
                const SizedBox(height: 16),
                NumberField(
                  controller: grams,
                  enabled: !saving,
                  min: kMinPortionGrams,
                  max: kMaxPortionGrams,
                  decoration: const InputDecoration(
                    labelText: AppStrings.portionGrams,
                    suffixText: AppStrings.grams,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MealSlot>(
                  initialValue: slot,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: AppStrings.chooseMealSlot),
                  items: [
                    for (final value in MealSlot.values)
                      DropdownMenuItem(value: value, child: Text(value.labelAr))
                  ],
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => slot = value);
                        },
                ),
                if (!valid || error != null) ...[
                  const SizedBox(height: 12),
                  Text(error ?? AppStrings.invalidPortion,
                      style: const TextStyle(color: AppPalette.danger)),
                ],
                const SizedBox(height: 20),
                GlassButton(
                  label:
                      saving ? AppStrings.saving : AppStrings.assistantSaveEdit,
                  busy: saving,
                  onPressed: valid ? save : null,
                ),
              ],
            ),
          ),
        ),
      );
}

class _ProposalButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ProposalButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        haptic: true,
        pressedScale: .96,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: filled ? AppPalette.accentGradient : null,
            color: filled ? null : AppPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: AppPalette.outline),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? AppPalette.onAccent : AppPalette.text,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      );
}

/// Renders the kind-specific detail rows inside a proposal card from
/// [Proposal.card] -- macros, before/after, deltas, the «تقديري» badge.
abstract final class _ProposalDetails {
  static List<Widget> rowsFor(Proposal proposal) {
    final card = proposal.card;
    final rows = <Widget>[];
    if (proposal.dateKey != null) {
      rows.add(_line(AppStrings.agentProposalDate(proposal.dateKey!)));
    }

    switch (proposal.kind) {
      case ProposalKind.logWeight:
        rows.add(_line('${AppStrings.agentWeightKg}: ${card['kg']}'));
      case ProposalKind.toggleExercise:
        rows.add(_line(
            '${card['name']}: ${card['done'] == true ? AppStrings.agentExerciseDone : AppStrings.agentExerciseNotDone}'));
      case ProposalKind.addPlanItem:
        rows.add(_line('${card['name']} · ${card['sets']} × ${card['reps']}'));
        rows.add(_line(
            '${AppStrings.agentTrainingDays}: ${(card['days_of_week'] as List).join('، ')}'));
      case ProposalKind.deletePlanItem:
      case ProposalKind.deleteWeight:
        break;
      case ProposalKind.swapMeal:
        rows.add(_line('${card['old_name']} â† ${card['new_name']}'));
        final delta = (card['delta'] as Map?)?.cast<String, num>();
        if (delta != null) rows.add(_deltaLine(delta));
      case ProposalKind.updateGrams:
        rows.add(_line(
          '${_fmt(card['old_grams'])} جم ← ${_fmt(card['new_grams'])} جم',
        ));
      case ProposalKind.removeEntry:
        rows.add(_line('${_fmt(card['kcal'])} سعرة'));
      case ProposalKind.createMeal:
        rows.add(_line('${card['component_count']} مكوّنات'));
        final macros = (card['macros'] as Map?)?.cast<String, num>();
        if (macros != null) rows.add(_macrosLine(macros));
      case ProposalKind.logFood:
      case ProposalKind.logMeal:
      case ProposalKind.logCustomComponent:
        final macros = (card['macros'] as Map?)?.cast<String, num>();
        if (macros != null) rows.add(_macrosLine(macros));
        if (card['estimated'] == true) rows.add(_estimatedBadge());
      case ProposalKind.restoreEntry:
      case ProposalKind.deleteMeal:
        break;
    }
    return rows;
  }

  static Widget _line(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          text,
          style: const TextStyle(color: AppPalette.muted, fontSize: 12.5),
        ),
      );

  static Widget _macrosLine(Map<String, num> macros) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${_fmt(macros['kcal'])} سعرة · بروتين ${_fmt(macros['protein_g'])} · '
          'كارب ${_fmt(macros['carbs_g'])} · دهون ${_fmt(macros['fat_g'])}',
          style: const TextStyle(color: AppPalette.muted, fontSize: 12.5),
        ),
      );

  static Widget _deltaLine(Map<String, num> delta) {
    final kcal = delta['kcal'] ?? 0;
    final sign = kcal > 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$sign${_fmt(kcal)} سعرة',
        style: TextStyle(
          color: kcal > 0 ? AppPalette.amber : AppPalette.emerald,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget _estimatedBadge() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppPalette.amber.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppPalette.amber.withValues(alpha: .35)),
          ),
          child: const Text(
            AppStrings.assistantEstimatedBadge,
            style: TextStyle(
              color: AppPalette.amber,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

  static String _fmt(Object? value) {
    if (value is! num) return '0';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

/// A confirmed action's summary, with a تراجع chip active for ten minutes
/// after execution. `AgentActionLog`'s full audit screen is Phase 5C; this
/// is the inline undo the plan asks Phase 5B to ship on its own.
class _ReceiptCard extends StatefulWidget {
  final ChatMessage message;
  const _ReceiptCard({required this.message});

  @override
  State<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<_ReceiptCard> {
  static const _undoWindow = Duration(minutes: 10);
  Timer? _ticker;

  // The "it's done" exhale: a single emerald bloom behind the card that
  // fades out over its first 600ms on screen. Not looping -- a receipt is a
  // settled fact, it should glow once and then sit quiet.
  double _bloom = 1;

  @override
  void initState() {
    super.initState();
    if (widget.message.receipt != null) _scheduleTick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !MotionSettings.enabled(context)) {
        if (mounted) setState(() => _bloom = 0);
        return;
      }
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _bloom = 0);
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Ticks every 20s for most of the window (no visible change that often
  /// anyway), then drops to every second in the final minute so the "تراجع"
  /// label can count down instead of just vanishing without warning.
  void _scheduleTick() {
    final receipt = widget.message.receipt;
    if (receipt == null) return;
    final remaining =
        _undoWindow - DateTime.now().difference(receipt.executedAt);
    if (remaining <= Duration.zero) {
      if (mounted) setState(() {});
      return;
    }
    final interval = remaining <= const Duration(minutes: 1)
        ? const Duration(seconds: 1)
        : const Duration(seconds: 20);
    _ticker = Timer(interval, () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  static String _formatRemaining(Duration d) {
    final totalSeconds = d.inSeconds.clamp(0, 599);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.message.receipt;
    final undone = widget.message.status == ChatMessageStatus.undone;
    final remaining = receipt == null
        ? Duration.zero
        : _undoWindow - DateTime.now().difference(receipt.executedAt);
    final withinWindow = remaining > Duration.zero;
    final canUndo =
        receipt != null && receipt.isUndoable && !undone && withinWindow;
    final justExpired =
        receipt != null && receipt.isUndoable && !undone && !withinWindow;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        child: AnimatedContainer(
          duration: MotionSettings.duration(
              context, const Duration(milliseconds: 600)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppPalette.emerald.withValues(alpha: .30 * _bloom),
                blurRadius: 24,
                spreadRadius: -6,
              ),
            ],
          ),
          child: GlassCard(
            elevation: GlassElevation.flush,
            tint: AppPalette.emerald,
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                AppMotion.pop(const Icon(
                  Icons.check_circle_rounded,
                  color: AppPalette.emerald,
                  size: 16,
                )),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    undone
                        ? '${widget.message.text} — ${AppStrings.assistantUndone}'
                        : widget.message.text,
                    style: TextStyle(
                      color: undone ? AppPalette.muted : AppPalette.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      decoration: undone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
                if (canUndo)
                  Pressable(
                    onTap: () => Get.find<ChatOrchestrator>()
                        .undoReceipt(widget.message.id),
                    pressedScale: .94,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        remaining <= const Duration(minutes: 1)
                            ? '${AppStrings.assistantUndo} · ${_formatRemaining(remaining)}'
                            : AppStrings.assistantUndo,
                        style: const TextStyle(
                          color: AppPalette.violet,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else if (justExpired)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text(
                      AppStrings.assistantUndoExpired,
                      style: TextStyle(
                        color: AppPalette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
