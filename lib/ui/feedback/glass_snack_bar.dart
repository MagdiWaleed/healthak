import 'package:flutter/material.dart';

import '../glass/glass_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/glass_tokens.dart';

enum GlassSnackTone { info, success, warning, error }

/// The one snackbar treatment for the app.
///
/// This deliberately uses filter-free [GlassCard], not a [BackdropFilter]. A
/// snackbar can coexist with the blurred header and bottom navigation, which
/// already consume the entire two-filter budget. The shared glass gradient,
/// specular edge, elevation, and status tint keep the material consistent
/// without adding a third expensive readback layer.
abstract final class GlassSnackBar {
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context,
    String message, {
    GlassSnackTone tone = GlassSnackTone.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.hide);

    final visual = _visualFor(tone);
    return messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        dismissDirection: DismissDirection.horizontal,
        duration: duration ??
            (onAction == null
                ? const Duration(seconds: 4)
                : const Duration(seconds: 6)),
        content: GlassCard(
          elevation: GlassElevation.panel,
          tint: visual.color,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
          child: Row(
            children: [
              Icon(visual.icon, size: 20, color: visual.color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppPalette.text,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: visual.color,
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static ({Color color, IconData icon}) _visualFor(GlassSnackTone tone) =>
      switch (tone) {
        GlassSnackTone.info => (
            color: AppPalette.mint,
            icon: Icons.info_outline_rounded,
          ),
        GlassSnackTone.success => (
            color: AppPalette.emerald,
            icon: Icons.check_circle_outline_rounded,
          ),
        GlassSnackTone.warning => (
            color: AppPalette.amber,
            icon: Icons.warning_amber_rounded,
          ),
        GlassSnackTone.error => (
            color: AppPalette.danger,
            icon: Icons.error_outline_rounded,
          ),
      };
}
