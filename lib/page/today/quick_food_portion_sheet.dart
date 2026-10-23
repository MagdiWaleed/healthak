import 'package:flutter/material.dart';

import '../../domain/day/day_log.dart';
import '../../domain/food/food_item.dart';
import '../../l10n/app_strings.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/food/food_photo.dart';
import '../../ui/format/number_input.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import 'today_controller.dart';

/// Confirms the portion of a catalog food before creating a day entry.
/// Catalog nutrition is per 100g, so selecting a row alone must not log it.
class QuickFoodPortionSheet extends StatefulWidget {
  final TodayController controller;
  final FoodItem food;

  const QuickFoodPortionSheet({
    required this.controller,
    required this.food,
    super.key,
  });

  static Future<void> show(
    BuildContext context,
    TodayController controller,
    FoodItem food,
  ) =>
      GlassSheet.show<void>(
        context,
        builder: (_) =>
            QuickFoodPortionSheet(controller: controller, food: food),
      );

  @override
  State<QuickFoodPortionSheet> createState() => _QuickFoodPortionSheetState();
}

class _QuickFoodPortionSheetState extends State<QuickFoodPortionSheet> {
  final _grams = TextEditingController(text: '100');
  MealSlot? _slot;
  bool _saving = false;
  String? _error;

  double? get _amount => parseNutritionAmount(_grams.text);
  bool get _canSave => _amount != null && _amount! > 0;

  @override
  void dispose() {
    _grams.dispose();
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
      await widget.controller.quickAddFood(
        widget.food,
        grams: _amount!,
        slot: _slot,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (messengerContext.mounted) {
        GlassSnackBar.show(messengerContext, AppStrings.quickFoodAdded,
            tone: GlassSnackTone.success);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = AppStrings.quickFoodSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final preview =
        _canSave ? widget.food.per100.forGrams(_amount!).kcal.round() : 0;
    return GlassSheet(
      title: AppStrings.quickFoodPortionTitle,
      topInset: 100,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm,
              AppSpacing.md, media.padding.bottom + AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                FoodPhoto(
                  asset: FoodPhoto.forFoodName(widget.food.name),
                  fallbackIcon: Icons.restaurant_outlined,
                  size: 64,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.food.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(AppStrings.foodPer100(widget.food.per100.kcal.round()),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                )),
              ]),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _grams,
                enabled: !_saving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: AppStrings.portionGrams,
                  suffixText: AppStrings.grams,
                ),
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
                    DropdownMenuItem(value: slot, child: Text(slot.labelAr)),
                ],
                onChanged:
                    _saving ? null : (slot) => setState(() => _slot = slot),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.portionCalories(preview),
                  style: const TextStyle(
                      color: AppPalette.text, fontWeight: FontWeight.w700)),
              if (!_canSave || _error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error ?? AppStrings.invalidPortion,
                    style: const TextStyle(color: AppPalette.danger)),
              ],
              const SizedBox(height: AppSpacing.md),
              GlassButton(
                label: _saving ? AppStrings.saving : AppStrings.addToDay,
                busy: _saving,
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
