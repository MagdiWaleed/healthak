import 'dart:async';

import 'package:flutter/material.dart';

import '../feedback/haptics.dart';
import '../theme/app_colors.dart';
import '../theme/motion_settings.dart';

class CheckTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Widget? leading;
  const CheckTile({
    required this.title,
    required this.checked,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.leading,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        checked: checked,
        enabled: enabled && onChanged != null,
        child: InkWell(
          onTap: !enabled || onChanged == null
              ? null
              : () {
                  unawaited(HapticPhrase.play(
                      checked ? AppHaptics.untick : AppHaptics.tick));
                  onChanged!(!checked);
                },
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(title,
                          style: TextStyle(
                            color: checked ? AppPalette.muted : AppPalette.text,
                            decoration:
                                checked ? TextDecoration.lineThrough : null,
                          )),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: const TextStyle(color: AppPalette.muted)),
                    ])),
                AnimatedContainer(
                  duration: MotionSettings.duration(
                      context, const Duration(milliseconds: 220)),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: checked ? AppPalette.emerald : AppPalette.surface,
                    border: Border.all(
                        color:
                            checked ? AppPalette.emerald : AppPalette.outline),
                    boxShadow:
                        checked ? AppPalette.glow(AppPalette.emerald) : null,
                  ),
                  child: AnimatedScale(
                    scale: checked ? 1 : .8,
                    duration: MotionSettings.duration(
                        context, const Duration(milliseconds: 300)),
                    curve: Curves.elasticOut,
                    child: checked
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: AppPalette.onAccent)
                        : null,
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
