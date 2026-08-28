import 'package:flutter/material.dart';

import '../theme/glass_tokens.dart';
import 'glass_surface.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final GlassElevation elevation;

  const GlassPanel(
      {required this.child,
      super.key,
      this.padding = const EdgeInsets.all(16),
      this.elevation = GlassElevation.panel});

  @override
  Widget build(BuildContext context) => GlassSurface(
        elevation: elevation,
        child: Padding(padding: padding, child: child),
      );
}
