import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'ticker_number.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final double? delta;
  const StatTile(
      {required this.label,
      required this.value,
      this.unit,
      this.delta,
      super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.outline),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: AppPalette.muted)),
              const SizedBox(height: 5),
              Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (int.tryParse(value) case final parsed?)
                      TickerNumber(
                          value: parsed, style: AppTypography.heroNumber)
                    else
                      Text(value, style: AppTypography.heroNumber),
                    if (unit != null) ...[
                      const SizedBox(width: 4),
                      Text(unit!,
                          style: const TextStyle(color: AppPalette.muted)),
                    ],
                  ]),
              if (delta != null)
                Text(
                    '${delta! > 0 ? '▲' : delta! < 0 ? '▼' : '–'} ${delta!.abs()}',
                    style: TextStyle(
                        color: delta! >= 0
                            ? AppPalette.emerald
                            : AppPalette.coral)),
            ]),
      );
}
