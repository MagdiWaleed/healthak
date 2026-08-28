import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/glass_tokens.dart';
import 'glass_decoration.dart';

/// A true blurred surface. **At most two of these may be mounted at once.**
///
/// [BackdropFilter] forces a `saveLayer` and reads back everything painted
/// beneath it, every frame. Two is the entire budget for the app -- in practice
/// the header and the nav bar. Everything else uses [GlassCard].
///
/// The limit is enforced by a debug-only live-instance counter. If that assert
/// fires, the fix is to switch the offending surface to [GlassCard], never to
/// raise the ceiling.
class GlassSurface extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;

  /// Body tint applied over the blur. Higher hides more of what is behind.
  final double tintTop;
  final double tintBottom;

  const GlassSurface({
    required this.child,
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.sigma = GlassTokens.blur,
    this.tintTop = .20,
    this.tintBottom = .10,
  });

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  static int _liveInstances = 0;

  @override
  void initState() {
    super.initState();
    assert(() {
      _liveInstances++;
      if (_liveInstances > 2) {
        throw FlutterError(
          'At most two GlassSurface instances may be mounted at once '
          '($_liveInstances are). Use GlassCard for anything that is not the '
          'header or the nav bar -- see lib/ui/glass/glass_card.dart.',
        );
      }
      return true;
    }());
  }

  @override
  void dispose() {
    assert(() {
      _liveInstances--;
      return true;
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: GlassDecoration.shadows,
          ),
          child: ClipRRect(
            // Mandatory. An unclipped BackdropFilter blurs the entire screen.
            borderRadius: widget.borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.sigma,
                sigmaY: widget.sigma,
                // Without mirroring, the sampled edge falls off to transparent
                // and the surface gets a cheap-looking soft rim.
                tileMode: TileMode.mirror,
              ),
              child: CustomPaint(
                foregroundPainter:
                    GlassEdgePainter(borderRadius: widget.borderRadius),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: GlassDecoration.body(
                      top: widget.tintTop,
                      bottom: widget.tintBottom,
                    ),
                    borderRadius: widget.borderRadius,
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: GlassDecoration.specular,
                            ),
                          ),
                        ),
                      ),
                      widget.child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
