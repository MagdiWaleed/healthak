import 'package:flutter/material.dart';
import 'number_field.dart';

class GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? errorText;
  final VoidCallback? onTap;
  final num? min;
  final num? max;
  final bool allowEmpty;

  const GlassField({
    required this.controller,
    required this.label,
    super.key,
    this.obscureText = false,
    this.keyboardType,
    this.errorText,
    this.onTap,
    this.min,
    this.max,
    this.allowEmpty = false,
  });

  @override
  Widget build(BuildContext context) => keyboardType == null
      ? TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onTap: onTap,
          decoration: InputDecoration(labelText: label, errorText: errorText),
        )
      : NumberField(
          controller: controller,
          min: min,
          max: max,
          allowEmpty: allowEmpty,
          decoration: InputDecoration(labelText: label, errorText: errorText),
        );
}
