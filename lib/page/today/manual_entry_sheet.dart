import 'package:flutter/material.dart';

import '../../domain/nutrition/macros.dart';
import '../../domain/day/day_log.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/format/number_input.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'today_controller.dart';

/// "أضف عنصراً يدوياً": a one-off dish with no catalog food behind it --
/// the user types its macros directly rather than building it as a
/// reusable, publishable component. Logs straight to today only through
/// [TodayController.logCustomEntry]; never touches `foods` or a meal
/// document.
class ManualEntrySheet extends StatefulWidget {
  final TodayController controller;

  const ManualEntrySheet({required this.controller, super.key});

  static Future<void> show(
    BuildContext context,
    TodayController controller,
  ) =>
      GlassSheet.show<void>(
        context,
        builder: (_) => ManualEntrySheet(controller: controller),
      );

  @override
  State<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<ManualEntrySheet> {
  final _name = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  bool _saving = false;
  String? _error;
  MealSlot? _slot;

  double _num(TextEditingController c) => parseNutritionAmount(c.text) ?? 0;
  bool get _validNumbers => [_protein, _carbs, _fat]
      .every((field) => parseNutritionAmount(field.text) != null);

  Macros get _macros =>
      Macros(protein: _num(_protein), carbs: _num(_carbs), fat: _num(_fat));

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _validNumbers && !_macros.isZero;

  @override
  void dispose() {
    _name.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    if (!widget.controller.canEditSelectedDay ||
        widget.controller.day.value == null) {
      setState(() => _error = AppStrings.dayNotEditable);
      return;
    }
    final messengerContext = Navigator.of(context).context;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.logCustomEntry(
          name: _name.text.trim(), macros: _macros, slot: _slot);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (messengerContext.mounted) {
        GlassSnackBar.show(messengerContext, AppStrings.entryAdded,
            tone: GlassSnackTone.success);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = AppStrings.saveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return GlassSheet(
      title: AppStrings.manualEntryTitle,
      topInset: 100,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md,
              media.padding.bottom + AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.manualEntryHint,
                style: TextStyle(color: AppPalette.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                enabled: !_saving,
                decoration:
                    const InputDecoration(labelText: AppStrings.dishName),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<MealSlot>(
                isExpanded: true,
                initialValue: _slot,
                decoration:
                    const InputDecoration(labelText: AppStrings.chooseMealSlot),
                hint: const Text(AppStrings.automaticMealSlot,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                items: [
                  for (final slot in MealSlot.values)
                    DropdownMenuItem(value: slot, child: Text(slot.labelAr))
                ],
                onChanged:
                    _saving ? null : (slot) => setState(() => _slot = slot),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _MacroField(
                      controller: _protein,
                      enabled: !_saving,
                      label: 'بروتين',
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MacroField(
                      controller: _carbs,
                      enabled: !_saving,
                      label: 'كارب',
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MacroField(
                      controller: _fat,
                      enabled: !_saving,
                      label: 'دهون',
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.calculatedKcal(_macros.kcal.round()),
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (!_validNumbers || _error != null) ...[
                Text(_error ?? AppStrings.invalidNutrition,
                    style: const TextStyle(
                        color: AppPalette.danger, fontSize: 12)),
                const SizedBox(height: AppSpacing.sm),
              ],
              GlassButton(
                label: _saving ? AppStrings.saving : AppStrings.addToDay,
                busy: _saving,
                icon: Icons.add_circle_outline,
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final bool enabled;

  const _MacroField({
    required this.controller,
    required this.label,
    required this.onChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) => TextField(
        enabled: enabled,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: 'غ'),
        onChanged: (_) => onChanged(),
      );
}
