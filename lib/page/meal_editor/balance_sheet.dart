import 'package:flutter/material.dart';

import '../../domain/nutrition/portion_solver.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'meal_editor_controller.dart';

/// "موازنة تلقائية": pick a calorie target, run the solver, review a
/// before/after diff, then apply or cancel. Locked entries (toggled in the
/// row list before opening this sheet) keep their weight and are excluded
/// from the diff.
class BalanceSheet extends StatefulWidget {
  final MealEditorController controller;

  const BalanceSheet({required this.controller, super.key});

  static Future<void> show(
    BuildContext context,
    MealEditorController controller,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BalanceSheet(controller: controller),
      );

  @override
  State<BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<BalanceSheet> {
  late final TextEditingController _target = TextEditingController(
    text: widget.controller.totals.kcal.round().toString(),
  );
  SolverResult? _preview;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  void _solve() {
    final target = double.tryParse(_target.text.trim());
    if (target == null || target <= 0) return;
    setState(() {
      _preview = widget.controller.autoBalance(targetKcal: target);
    });
  }

  void _apply() {
    final result = _preview;
    if (result == null || !result.solved) return;
    widget.controller.applyBalance(result);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final preview = _preview;

    return Padding(
      padding: EdgeInsets.only(
        bottom: media.viewInsets.bottom,
        top: media.padding.top + 120,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg)),
        child: DecoratedBox(
          decoration:
              BoxDecoration(color: AppPalette.surface.withValues(alpha: .97)),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md,
                media.padding.bottom + AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('موازنة تلقائية',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppPalette.text)),
                const SizedBox(height: 4),
                const Text(
                  'المكوّنات المثبّتة تحتفظ بوزنها؛ يوزَّع الباقي على الهدف.',
                  style: TextStyle(color: AppPalette.muted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعرات المستهدفة',
                    suffixText: 'سعرة',
                  ),
                  onSubmitted: (_) => _solve(),
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassButton(
                  label: 'احسب',
                  icon: Icons.auto_awesome,
                  onPressed: _solve,
                ),
                if (preview != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (!preview.solved)
                    Text(
                      preview.messageAr ?? 'تعذر الحساب',
                      style: const TextStyle(color: AppPalette.amber),
                    )
                  else ...[
                    Text('المعاينة', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    for (final row in preview.diff)
                      if ((row.to - row.from).abs() > 0.5)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(row.name)),
                              Text(
                                '${row.from.round()} ← ${row.to.round()}',
                                style: const TextStyle(
                                  fontFeatures: AppTypography.tabular,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: GlassButton(label: 'تطبيق', onPressed: _apply),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
