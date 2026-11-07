import 'package:flutter/material.dart';

import '../motion/pressable.dart';
import '../theme/app_colors.dart';

class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const NeonButton(
      {required this.label,
      this.onPressed,
      this.loading = false,
      this.icon,
      super.key});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: loading ? null : onPressed,
        pressedScale: .97,
        child: Semantics(
          button: true,
          enabled: onPressed != null && !loading,
          child: Opacity(
              opacity: onPressed == null ? .5 : 1,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppPalette.accentGradient,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: AppPalette.glow(AppPalette.emerald),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (loading) ...[
                    const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppPalette.onAccent)),
                    const SizedBox(width: 8),
                  ] else if (icon != null) ...[
                    Icon(icon, color: AppPalette.onAccent),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppPalette.onAccent,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
              )),
        ),
      );
}
