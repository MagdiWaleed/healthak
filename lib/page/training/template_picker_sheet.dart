import 'package:flutter/material.dart';

import '../../domain/training/workout_templates.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';
import 'equipment_sheet.dart';

typedef TemplateChoice = ({WorkoutTemplate template, List<int> days});

/// Two steps in one sheet: pick a ready plan (with what it is, how long, and
/// what it needs), then pick exactly as many weekdays as it has sessions.
class TemplatePickerSheet extends StatefulWidget {
  const TemplatePickerSheet({super.key});

  static Future<TemplateChoice?> show(BuildContext context) =>
      GlassSheet.show<TemplateChoice>(context,
          builder: (_) => const TemplatePickerSheet());

  @override
  State<TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<TemplatePickerSheet> {
  WorkoutTemplate? chosen;
  final days = <int>{};

  void _choose(WorkoutTemplate t) => setState(() {
        chosen = t;
        days
          ..clear()
          ..addAll(t.defaultDays);
      });

  /// Sessions go onto the chosen days in week order (Saturday first, the
  /// usual start of the week here).
  List<int> get _orderedDays {
    int rank(int d) => (d - DateTime.saturday) % 7;
    return days.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  @override
  Widget build(BuildContext context) {
    final t = chosen;
    return GlassSheet(
      title: t == null
          ? AppStrings.trainingTemplates
          : AppStrings.templateTitles[t.id],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: t == null ? _list(context) : _days(context, t),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final have = userEquipmentOrAll();
    final fitting = kWorkoutTemplates.where((t) => t.fits(have)).toList();
    final home = fitting.where((t) => t.kind == TemplateKind.home).toList();
    final gym = fitting.where((t) => t.kind == TemplateKind.gym).toList();
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
      child: ListView(shrinkWrap: true, children: [
        if (home.isNotEmpty) _header(AppStrings.templatesHome),
        for (final t in home) _card(t),
        if (gym.isNotEmpty) _header(AppStrings.templatesGym),
        for (final t in gym) _card(t),
      ]),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(text,
            style: const TextStyle(
                color: AppPalette.muted, fontWeight: FontWeight.w700)),
      );

  Widget _card(WorkoutTemplate t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _choose(t),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.templateTitles[t.id]!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(AppStrings.templateDescriptions[t.id]!,
                    style: const TextStyle(color: AppPalette.muted)),
                const SizedBox(height: 8),
                Text(
                  '${AppStrings.templateMeta(t.sessions.length, t.minutesPerSession)}'
                  ' · ${needsLabel(t.needs)}',
                  style: const TextStyle(
                      color: AppPalette.emerald, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _days(BuildContext context, WorkoutTemplate t) {
    final n = t.sessions.length;
    final ready = days.length == n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.pickTemplateDays(n),
            style: const TextStyle(color: AppPalette.muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in const [6, 7, 1, 2, 3, 4, 5])
            FilterChip(
              label: Text(AppStrings.weekdays[d - 1]),
              selected: days.contains(d),
              onSelected: (on) => setState(() {
                if (on && days.length < n) days.add(d);
                if (!on) days.remove(d);
              }),
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          TextButton(
              onPressed: () => setState(() => chosen = null),
              child: const Text(AppStrings.assistantCancel)),
          const SizedBox(width: 8),
          Expanded(
            child: NeonButton(
              label: AppStrings.applyTemplate,
              onPressed: ready
                  ? () => Navigator.pop<TemplateChoice>(
                      context, (template: t, days: _orderedDays))
                  : null,
            ),
          ),
        ]),
      ],
    );
  }
}
