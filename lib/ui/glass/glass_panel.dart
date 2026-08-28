import 'package:flutter/material.dart';

import 'glass_surface.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassPanel(
      {required this.child,
      super.key,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => GlassSurface(
        child: Padding(padding: padding, child: child),
      );
}
