import 'package:flutter/material.dart';

import '../../domain/nutrition/macros.dart';
import '../../ui/components/glass_button.dart';
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

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Macros get _macros =>
      Macros(protein: _num(_protein), carbs: _num(_carbs), fat: _num(_fat));

  bool get _canSave => _name.text.trim().isNotEmpty && !_macros.isZero;

  @override
  void dispose() {
    _name.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave) return;
    widget.controller.logCustomEntry(name: _name.text.trim(), macros: _macros);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return GlassSheet(
      title: 'إضافة عنصر يدوي',
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
                'لطبق ليس له مكوّن جاهز -- اكتب اسمه وقيمه الغذائية كما هي، '
                'يُضاف لليوم فقط ولا يُحفظ كمكوّن يمكن نشره.',
                style: TextStyle(color: AppPalette.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'اسم الطبق'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _MacroField(
                      controller: _protein,
                      label: 'بروتين',
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MacroField(
                      controller: _carbs,
                      label: 'كارب',
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MacroField(
                      controller: _fat,
                      label: 'دهون',
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${_macros.kcal.round()} سعرة (محسوبة تلقائياً)',
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GlassButton(
                label: 'إضافة لليوم',
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

  const _MacroField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: 'غ'),
        onChanged: (_) => onChanged(),
      );
}
