import 'package:flutter/material.dart';

import 'numeric_stepper.dart';

/// Portion input for a nested meal reference: shown and typed as a
/// percentage (`scale: 0.5` reads and edits as `50`), stepped by 10 points.
///
/// A [MealRefEntry] has no grams of its own -- [scale] multiplies every leaf
/// gram of the meal it references, so a half portion is `scale: 0.5`. Percent
/// is what a person means by "give me half of this meal," where a raw
/// decimal factor is not.
class ScaleStepper extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;

  const ScaleStepper({required this.scale, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) => NumericStepper(
        value: scale,
        onChanged: onChanged,
        step: 0.1,
        min: 0.05,
        max: 10,
        format: (v) => '${(v * 100).round()}٪',
        editText: (v) => (v * 100).round().toString(),
        parse: (text) {
          final percent = double.tryParse(text);
          return percent == null ? null : percent / 100;
        },
      );
}
