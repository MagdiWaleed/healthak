import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GramStepper extends StatelessWidget {
  final double grams;
  final ValueChanged<double> onChanged;
  final double step;

  const GramStepper(
      {required this.grams, required this.onChanged, super.key, this.step = 5});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
              onPressed: () => _set((grams - step).clamp(0, double.infinity)),
              icon: const Icon(Icons.remove)),
          Text('${grams.round()} غ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
              onPressed: () => _set(grams + step), icon: const Icon(Icons.add)),
        ],
      );

  void _set(double value) {
    HapticFeedback.selectionClick();
    onChanged(value);
  }
}
