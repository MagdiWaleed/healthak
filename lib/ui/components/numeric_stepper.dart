import 'dart:async';

import 'package:flutter/material.dart';

import '../feedback/haptics.dart';
import '../motion/pressable.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../format/number_input.dart';
import 'ticker_number.dart';
import 'number_field.dart';

/// Tap-either-arrow-to-step, long-press-to-repeat, tap-the-number-to-type
/// numeric input. [GramStepper] and the meal editor's scale control are both
/// thin formatters over this -- the interaction (and the failure modes it
/// avoids; see [GramStepper]'s doc) is identical, only the unit differs.
class NumericStepper extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;
  final double? inputMin;
  final double? inputMax;

  /// How the current value renders when not being edited, e.g. `'120 غ'`.
  final String Function(double value) format;

  /// Parses the raw text field content back to a value, or `null` if it
  /// can't be interpreted -- in which case the last known-good value is kept
  /// rather than falling through to zero.
  final double? Function(String text) parse;

  /// Pre-fills the text field with this instead of the raw value when
  /// editing starts, e.g. formatting `0.5` as `'50'` for a percent control.
  final String Function(double value)? editText;

  const NumericStepper({
    required this.value,
    required this.onChanged,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.parse,
    super.key,
    this.editText,
    this.inputMin,
    this.inputMax,
  });

  @override
  State<NumericStepper> createState() => _NumericStepperState();
}

class _NumericStepperState extends State<NumericStepper> {
  bool _editing = false;
  late final TextEditingController _text;
  Timer? _repeat;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _editStringFor(widget.value));
  }

  @override
  void didUpdateWidget(covariant NumericStepper old) {
    super.didUpdateWidget(old);
    // An external change (e.g. the portion solver ran) must overwrite the
    // field, but only while the user isn't mid-edit -- otherwise a
    // background recompute would erase what they're typing.
    if (!_editing && old.value != widget.value) {
      _text.text = _editStringFor(widget.value);
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _text.dispose();
    super.dispose();
  }

  String _editStringFor(double value) =>
      widget.editText?.call(value) ?? value.toString();

  double get _clamped => widget.value.clamp(widget.min, widget.max);

  void _set(double value) {
    final clamped = value.clamp(widget.min, widget.max);
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  void _startRepeat(double direction) {
    unawaited(HapticPhrase.play(AppHaptics.step));
    _set(_clamped + widget.step * direction);
    // A short initial delay before repeating, so a normal tap never fires a
    // second step it didn't ask for.
    _repeat = Timer(const Duration(milliseconds: 350), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
        unawaited(HapticPhrase.play(AppHaptics.step));
        _set(_clamped + widget.step * direction);
      });
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _startEditing() {
    _text.text = _editStringFor(widget.value);
    _text.selection =
        TextSelection(baseOffset: 0, extentOffset: _text.text.length);
    setState(() => _editing = true);
  }

  void _commitEditing() {
    final normalized = parseNutritionAmount(_text.text);
    final parsed =
        normalized == null ? null : widget.parse(normalized.toString());
    if (parsed == null || parsed < widget.min || parsed > widget.max) return;
    setState(() => _editing = false);
    _set(parsed);
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Arrow(
            icon: Icons.remove_rounded,
            onTapDown: () => _startRepeat(-1),
            onTapUp: _stopRepeat,
          ),
          SizedBox(
            width: 68,
            child: _editing
                ? NumberField(
                    controller: _text,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    min: widget.inputMin ?? widget.min,
                    max: widget.inputMax ?? widget.max,
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.text,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: UnderlineInputBorder(),
                    ),
                    onSubmitted: (_) => _commitEditing(),
                    onTapOutside: (_) => _commitEditing(),
                  )
                : Pressable(
                    onTap: _startEditing,
                    child: Center(
                      child: TickerNumber(
                        value: _clamped.round(),
                        format: (_) => widget.format(_clamped),
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.text,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ),
                  ),
          ),
          _Arrow(
            icon: Icons.add_rounded,
            onTapDown: () => _startRepeat(1),
            onTapUp: _stopRepeat,
          ),
        ],
      );
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;

  const _Arrow(
      {required this.icon, required this.onTapDown, required this.onTapUp});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTapDown(),
        onTapUp: (_) => onTapUp(),
        onTapCancel: onTapUp,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.raised,
          ),
          child: Icon(icon, size: 18, color: AppPalette.text),
        ),
      );
}
