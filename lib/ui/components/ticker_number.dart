import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/motion_settings.dart';

/// A direction-aware digit transition for changing numeric values.
class TickerNumber extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final TextAlign textAlign;
  final String Function(int value) format;

  const TickerNumber({
    required this.value,
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.format = _defaultFormat,
  });

  static String _defaultFormat(int value) => value.toString();

  @override
  State<TickerNumber> createState() => _TickerNumberState();
}

class _TickerNumberState extends State<TickerNumber> {
  late int _previous = widget.value;

  @override
  void didUpdateWidget(covariant TickerNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _previous = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    final rising = widget.value >= _previous;
    final motionEnabled = MotionSettings.enabled(context);
    final style = widget.style?.copyWith(fontFeatures: AppTypography.tabular) ??
        const TextStyle(fontFeatures: AppTypography.tabular);

    return AnimatedSwitcher(
      duration: MotionSettings.duration(
        context,
        const Duration(milliseconds: 250),
      ),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      transitionBuilder: (child, animation) {
        if (!motionEnabled) return child;
        final incoming = child.key == ValueKey(widget.value);
        final direction = rising ? 1.0 : -1.0;
        final begin =
            incoming ? Offset(0, .35 * direction) : Offset(0, -.35 * direction);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        widget.format(widget.value),
        key: ValueKey(widget.value),
        textAlign: widget.textAlign,
        style: style,
      ),
    );
  }
}
