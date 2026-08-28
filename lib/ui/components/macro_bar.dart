import 'package:flutter/material.dart';

class MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  const MacroBar(
      {required this.label,
      required this.value,
      required this.target,
      required this.color,
      super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label)),
            Text('${value.round()} / ${target.round()} غ')
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(
              value: target <= 0 ? 0 : (value / target).clamp(0, 1),
              color: color),
        ],
      );
}
