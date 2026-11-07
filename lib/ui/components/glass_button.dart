import 'package:flutter/material.dart';

import 'neon_button.dart';

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
  Widget build(BuildContext context) => NeonButton(
        label: label,
        onPressed: busy ? null : onPressed,
        loading: busy,
        icon: icon,
      );
}
