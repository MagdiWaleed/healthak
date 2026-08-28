import 'package:flutter/material.dart';

class GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const GlassChip(
      {required this.label, super.key, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) => FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onTap == null ? null : (_) => onTap!(),
      );
}
