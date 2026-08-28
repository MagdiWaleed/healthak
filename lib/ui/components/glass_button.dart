import 'package:flutter/material.dart';

import '../motion/pressable.dart';
import '../theme/app_colors.dart';

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GlassButton(
      {required this.label, super.key, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onPressed,
        haptic: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
              gradient: AppPalette.accentGradient,
              borderRadius: BorderRadius.circular(18)),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppPalette.ink),
                  const SizedBox(width: 8)
                ],
                Text(label,
                    style: const TextStyle(
                        color: AppPalette.ink, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}
