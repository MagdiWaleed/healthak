import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  const GlassButton(
      {required this.label,
      super.key,
      this.onPressed,
      this.icon,
      this.busy = false});

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.emerald,
          foregroundColor: AppPalette.onAccent,
          disabledBackgroundColor: AppPalette.soft,
          disabledForegroundColor: AppPalette.muted,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              Icon(icon),
              const SizedBox(width: 8)
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      );
}
