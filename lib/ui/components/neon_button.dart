import 'package:flutter/material.dart';

import '../motion/pressable.dart';
import '../theme/app_colors.dart';

class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const NeonButton(
      {required this.label, this.onPressed, this.loading = false, super.key});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: loading ? null : onPressed,
        pressedScale: .97,
        child: Opacity(
          opacity: onPressed == null ? .5 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppPalette.accentGradient,
              borderRadius: BorderRadius.circular(99),
              boxShadow: AppPalette.glow(AppPalette.emerald),
            ),
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppPalette.onAccent))
                : Text(label,
                    style: const TextStyle(
                        color: AppPalette.onAccent,
                        fontWeight: FontWeight.w800)),
          ),
        ),
      );
}
