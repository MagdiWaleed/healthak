import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../theme/app_colors.dart';

class StreakChip extends StatelessWidget {
  final int count;
  const StreakChip({required this.count, super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: AppStrings.streakDays(count),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppPalette.raised,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
                color: count >= 3 ? AppPalette.coral : AppPalette.outline),
            boxShadow: count >= 3 ? AppPalette.glow(AppPalette.coral) : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_fire_department_rounded,
                color: count >= 3 ? AppPalette.coral : AppPalette.muted,
                size: 19),
            const SizedBox(width: 5),
            Text('$count',
                style: const TextStyle(
                    color: AppPalette.text, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}
