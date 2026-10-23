import 'package:flutter/material.dart';

import '../../data/repositories/food_repository.dart';
import '../../domain/food/food_item.dart';
import '../../domain/nutrition/macros.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/components/glass_chip.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// The catalog's "مكوّن جديد": name, category, and macros per 100g.
///
/// Everything here is per 100 grams, matching how every other component in
/// the catalog is stored -- the portion is chosen later, wherever the
/// component gets used. Calories are shown but never entered: they are
/// derived from the macros through the same Atwater factors as the rest of
/// the app, so a component can't be saved claiming an energy value its own
/// macros contradict.
///
/// Resolves to the created [FoodItem], or `null` if dismissed.
class ComponentEditorSheet extends StatefulWidget {
  const ComponentEditorSheet({super.key});

  static Future<FoodItem?> show(BuildContext context) =>
      GlassSheet.show<FoodItem>(
        context,
        builder: (_) => const ComponentEditorSheet(),
      );

  @override
  State<ComponentEditorSheet> createState() => _ComponentEditorSheetState();
}

class _ComponentEditorSheetState extends State<ComponentEditorSheet> {
  static const _categories = ['بروتين', 'كارب', 'دهون'];

  final _name = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  String? _category;

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
    final name = _name.text.trim();
    Navigator.of(context).pop(
      FoodItem(
        // Replaced by Firestore's assigned id on write; never persisted.
        id: '',
        name: name,
        // Folded exactly the way the migration script folded every catalog
        // row, so a component typed here is findable by the same search that
        // finds a migrated one.
        nameNormalized: foldArabic(name),
        category: _category,
        per100: _macros,
        kcalPer100: _macros.kcal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return GlassSheet(
      title: 'مكوّن جديد',
      topInset: 80,
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
                'القيم لكل 100 غرام. يُحفظ في مكوّناتك الخاصة ولا يظهر لغيرك.',
                style: TextStyle(color: AppPalette.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'اسم المكوّن'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('التصنيف', style: TextStyle(color: AppPalette.muted)),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                children: [
                  for (final category in _categories)
                    GlassChip(
                      label: category,
                      selected: _category == category,
                      // Tapping the selected chip clears it: a category is
                      // optional, so there has to be a way back out of one.
                      onTap: () => setState(() =>
                          _category = _category == category ? null : category),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
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
                '${_macros.kcal.round()} سعرة / 100غ (محسوبة تلقائياً)',
                style: const TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GlassButton(
                label: 'حفظ المكوّن',
                icon: Icons.check_rounded,
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
