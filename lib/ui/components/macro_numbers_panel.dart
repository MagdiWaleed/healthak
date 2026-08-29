import 'package:flutter/material.dart';

import '../../domain/nutrition/macros.dart';
import '../../l10n/app_strings.dart';
import '../glass/glass_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'macro_bar.dart';
import 'ticker_number.dart';

/// Readable macro progress for Today. The ring stays the visual headline;
/// this panel makes its three inner arcs useful when a user needs exact grams.
class MacroNumbersPanel extends StatefulWidget {
  final Macros consumed;
  final Macros target;
  final Macros planned;
  final int animationTrigger;

  const MacroNumbersPanel({
    required this.consumed,
    required this.target,
    required this.planned,
    required this.animationTrigger,
    super.key,
  });

  @override
  State<MacroNumbersPanel> createState() => _MacroNumbersPanelState();
}

class _MacroNumbersPanelState extends State<MacroNumbersPanel> {
  bool _showPlanned = false;

  @override
  Widget build(BuildContext context) {
    final values = _showPlanned ? widget.planned : widget.consumed;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              button: true,
              label: AppStrings.macroProgressToggle,
              child: TextButton(
                onPressed: () => setState(() => _showPlanned = !_showPlanned),
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_showPlanned
                    ? AppStrings.macroPlanned
                    : AppStrings.macroConsumed),
              ),
            ),
          ),
          _MacroProgressRow(
            label: AppStrings.protein,
            value: values.protein,
            target: widget.target.protein,
            planned: widget.planned.protein,
            color: AppPalette.emerald,
            animationTrigger: widget.animationTrigger,
          ),
          const SizedBox(height: AppSpacing.sm),
          _MacroProgressRow(
            label: AppStrings.carbs,
            value: values.carbs,
            target: widget.target.carbs,
            planned: widget.planned.carbs,
            color: AppPalette.amber,
            animationTrigger: widget.animationTrigger,
            stagger: const Duration(milliseconds: 60),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MacroProgressRow(
            label: AppStrings.fat,
            value: values.fat,
            target: widget.target.fat,
            planned: widget.planned.fat,
            color: AppPalette.violet,
            animationTrigger: widget.animationTrigger,
            stagger: const Duration(milliseconds: 120),
          ),
        ],
      ),
    );
  }
}

class _MacroProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final double planned;
  final Color color;
  final int animationTrigger;
  final Duration stagger;

  const _MacroProgressRow({
    required this.label,
    required this.value,
    required this.target,
    required this.planned,
    required this.color,
    required this.animationTrigger,
    this.stagger = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final over = value > target && target > 0;
    final numberColor = over ? AppPalette.amber : AppPalette.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(label)),
            TickerNumber(
              value: value.round(),
              format: (number) => '$number / ${target.round()} ${AppStrings.grams}',
              style: TextStyle(
                color: numberColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        MacroBar(
          label: '',
          value: value,
          target: target,
          planned: planned,
          color: color,
          animationTrigger: animationTrigger,
          stagger: stagger,
          showHeader: false,
        ),
      ],
    );
  }
}
