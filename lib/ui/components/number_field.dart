import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../format/number_input.dart';

/// Numeric input with select-all on focus entry and visible range feedback.
class NumberField extends StatefulWidget {
  const NumberField({
    required this.controller,
    required this.decoration,
    super.key,
    this.min,
    this.max,
    this.allowEmpty = false,
    this.enabled,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.textInputAction,
    this.style,
    this.onChanged,
    this.onValidChanged,
    this.onSubmitted,
    this.onTapOutside,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final num? min;
  final num? max;
  final bool allowEmpty;
  final bool? enabled;
  final bool autofocus;
  final TextAlign textAlign;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onValidChanged;
  final ValueChanged<String>? onSubmitted;
  final TapRegionCallback? onTapOutside;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  bool _touched = false;

  bool get _valid {
    if (widget.controller.text.trim().isEmpty && widget.allowEmpty) return true;
    final value = parseNutritionAmount(widget.controller.text);
    return value != null &&
        widget.controller.text.trim().isNotEmpty &&
        (widget.min == null || value >= widget.min!) &&
        (widget.max == null || value <= widget.max!);
  }

  void _onFocus() {
    if (!_focus.hasFocus) return;
    widget.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.controller.text.length,
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        textAlign: widget.textAlign,
        textInputAction: widget.textInputAction,
        style: widget.style,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: widget.decoration.copyWith(
          errorText: _touched && !_valid
              ? (widget.decoration.errorText ?? AppStrings.invalidNumberRange)
              : widget.decoration.errorText,
        ),
        onChanged: (text) {
          setState(() => _touched = true);
          widget.onChanged?.call(text);
          widget.onValidChanged?.call(_valid);
        },
        onSubmitted: widget.onSubmitted,
        onTapOutside: widget.onTapOutside,
      );
}
