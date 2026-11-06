part of '../assistant_tab.dart';

class AssistantEmptyConversation extends StatelessWidget {
  final bool active;
  final String? snapshot;
  final Future<void> Function(String) onSelected;
  const AssistantEmptyConversation(
      {required this.active,
      required this.snapshot,
      required this.onSelected,
      super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AgentPulse(active: active),
              const SizedBox(height: 14),
              Text(
                DateTime.now().hour < 12
                    ? AppStrings.agentGreetingMorning
                    : DateTime.now().hour < 18
                        ? AppStrings.agentGreetingAfternoon
                        : AppStrings.agentGreetingEvening,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: AppPalette.emerald),
              ),
              const SizedBox(height: 9),
              Text(
                AppStrings.assistantEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 26),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final prompt in [
                  snapshot?.contains('البروتين غير متاح') == true
                      ? AppStrings.assistantSuggestionRemaining
                      : AppStrings.agentSuggestionProteinLeft,
                  snapshot?.contains('المتبقي من السعرات غير متاح') == true
                      ? AppStrings.assistantSuggestionDinner
                      : AppStrings.agentSuggestionDinnerRemaining,
                  snapshot?.contains('التمرين 0/0') == true
                      ? AppStrings.agentSuggestionStartTraining
                      : AppStrings.agentSuggestionWorkoutToday,
                  snapshot?.contains('آخر وزن غير متاح') == true
                      ? AppStrings.agentSuggestionStartWeight
                      : AppStrings.agentSuggestionWeightTrend,
                ])
                  ActionChip(
                      label: Text(prompt), onPressed: () => onSelected(prompt)),
              ]),
            ],
          ),
        ),
      );
}

class _DisclosureCard extends StatelessWidget {
  final Future<void> Function() onAccept;
  const _DisclosureCard({required this.onAccept});

  @override
  Widget build(BuildContext context) => GlassCard(
        elevation: GlassElevation.panel,
        highlighted: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.emerald.withValues(alpha: .14),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppPalette.emerald,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  AppStrings.assistantDisclosureTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              AppStrings.assistantDisclosureBody,
              style: TextStyle(color: AppPalette.muted, height: 1.6),
            ),
            const SizedBox(height: 14),
            GlassButton(
              label: AppStrings.assistantDisclosureConfirm,
              icon: Icons.arrow_back_rounded,
              onPressed: onAccept,
            ),
          ],
        ),
      );
}

class _SuggestionRail extends StatelessWidget {
  final Future<void> Function(String text) onSelected;
  const _SuggestionRail({required this.onSelected});

  /// Swaps one or two chips for the meal that actually matters right now --
  /// a "اقترح فطورًا" at 9pm reads as the assistant not knowing what time it
  /// is. The universal ones (remaining/today) stay in every slot since
  /// they're useful regardless of the hour.
  static List<String> suggestionsFor(DateTime now) {
    final hour = now.hour;
    if (hour < 11) {
      return const [
        AppStrings.assistantSuggestionBreakfast,
        AppStrings.assistantSuggestionRemaining,
        AppStrings.assistantSuggestionProtein,
        AppStrings.assistantSuggestionToday,
      ];
    }
    if (hour < 16) {
      return const [
        AppStrings.assistantSuggestionLunch,
        AppStrings.assistantSuggestionRemaining,
        AppStrings.assistantSuggestionToday,
        AppStrings.assistantSuggestionWeek,
      ];
    }
    if (hour < 21) {
      return const [
        AppStrings.assistantSuggestionDinner,
        AppStrings.assistantSuggestionToday,
        AppStrings.assistantSuggestionRemaining,
        AppStrings.assistantSuggestionProtein,
      ];
    }
    return const [
      AppStrings.assistantSuggestionToday,
      AppStrings.assistantSuggestionGoal,
      AppStrings.assistantSuggestionWeek,
      AppStrings.assistantSuggestionRemaining,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = suggestionsFor(DateTime.now());
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Pressable(
          haptic: true,
          onTap: () => onSelected(suggestions[index]),
          pressedScale: .96,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppPalette.outline,
              ),
            ),
            child: Text(
              suggestions[index],
              style: const TextStyle(
                color: AppPalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final RxBool sending;
  final Future<void> Function() onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        child: GlassCard(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 5, 6, 5),
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: AppStrings.assistantComposerHint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => Obx(() {
                  final enabled =
                      value.text.trim().isNotEmpty && !sending.value;
                  return Pressable(
                    onTap: enabled ? onSend : null,
                    haptic: true,
                    pressedScale: .90,
                    child: AnimatedContainer(
                      duration: MotionSettings.duration(
                        context,
                        const Duration(milliseconds: 180),
                      ),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: enabled ? AppPalette.emerald : AppPalette.soft,
                      ),
                      child: sending.value
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppPalette.violet,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: enabled
                                  ? AppPalette.onAccent
                                  : AppPalette.muted,
                            ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      );
}
