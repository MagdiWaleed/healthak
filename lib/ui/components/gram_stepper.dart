import 'package:flutter/material.dart';

import 'numeric_stepper.dart';

/// Weight input: tap either arrow to step, long-press to repeat, tap the
/// number to type an exact value.
///
/// Replaces a `Get.defaultDialog` that ran `double.parse` on every keystroke
/// -- a lone `-` or `.` mid-edit threw -- and defaulted its helper text field
/// to `0`, so confirming before typing anything zeroed the component. This
/// widget can't reach either failure mode: the field only ever contains what
/// [TextInputType.number] accepted, and grams below 1 clamp to 1 rather than
/// falling through to zero.
class GramStepper extends StatelessWidget {
  final double grams;
  final ValueChanged<double> onChanged;
  final double step;
  final double minGrams;
  final double maxGrams;

  const GramStepper({
    required this.grams,
    required this.onChanged,
    super.key,
    this.step = 5,
    this.minGrams = 1,
    this.maxGrams = 5000,
  });

  @override
  Widget build(BuildContext context) => NumericStepper(
        value: grams,
        onChanged: onChanged,
        step: step,
        min: minGrams,
        max: maxGrams,
        format: (v) => '${v.round()} غ',
        editText: (v) => v.round().toString(),
        parse: (text) => double.tryParse(text),
      );
}
