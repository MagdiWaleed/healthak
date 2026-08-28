import 'package:flutter/material.dart';

import '../motion/pressable.dart';
import '../theme/app_spacing.dart';
import 'glass_decoration.dart';

/// The list-safe glass surface: tint, specular sheen, lit edge, shadow --
/// and **no [BackdropFilter]**.
///
/// This is the most important rule in the design system. A blur inside a
/// scrolling viewport forces a `saveLayer` and a full read of everything
/// beneath it, per card, per frame. Against the aurora this treatment is
/// visually near-identical and costs nothing.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  /// Lifts the tint and edge. Use for the one card that should draw the eye.
  final bool highlighted;

  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.onLongPress,
    this.borderRadius =
        const BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: GlassDecoration.body(
          top: highlighted ? .22 : .16,
          bottom: highlighted ? .09 : .055,
        ),
        boxShadow: GlassDecoration.shadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CustomPaint(
          // Painted over the content so the lit edge is never covered by a
          // child that fills the card, such as an image.
          foregroundPainter: GlassEdgePainter(
            borderRadius: borderRadius,
            intensity: highlighted ? 1.35 : 1.0,
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(gradient: GlassDecoration.specular),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );

    if (onTap == null && onLongPress == null) return surface;

    // Deliberately not InkWell: a Material ripple over a translucent tint
    // renders as a grey smear rather than as a press.
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: .985,
      haptic: true,
      child: surface,
    );
  }
}
