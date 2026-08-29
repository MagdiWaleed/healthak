import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/motion_settings.dart';

/// A list row that piles up under the header instead of scrolling away.
///
/// Once a row reaches [stackTop] it stops moving with the list and pins
/// there, shrinking and dimming by a little for each row-height of scroll
/// past it, so the ones already parked read as a deck of glass edges rather
/// than a single card. The next row slides over the deck and joins it. After
/// [maxVisible] rows the pile stops growing -- everything deeper lands on the
/// same spot, hidden behind the cards in front of it.
///
/// Layout is untouched: this only ever paints a [Transform], so the sliver
/// below still measures, keys, and recycles rows exactly as before. That is
/// also what makes the measurement safe -- [_boxKey] sits *outside* the
/// transform, so reading its position can never feed back into the offset
/// that moved it.
///
/// Pinned rows are drawn from a layout position above the viewport, so the
/// scroll view needs a `cacheExtent` big enough to keep them alive; see
/// [kStackingCacheExtent].
class StackingCard extends StatefulWidget {
  final Widget child;

  /// Where the pile forms, in pixels from the top of the screen. Set this to
  /// the bottom of whatever pinned chrome the rows should tuck under.
  final double stackTop;

  /// The visible edge left showing per parked row.
  final double spacing;

  /// How many edges stay visible before the pile stops deepening.
  final int maxVisible;

  /// Corner radius of the opaque plate slipped behind a parked row. Match it
  /// to the card being stacked.
  final BorderRadius borderRadius;

  const StackingCard({
    required this.child,
    required this.stackTop,
    super.key,
    this.spacing = 9,
    this.maxVisible = 3,
    this.borderRadius =
        const BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
  });

  @override
  State<StackingCard> createState() => _StackingCardState();
}

/// Rows park above the top of the viewport, so the default 250 is not enough
/// to keep the deepest of them from being recycled out from under the pile.
const double kStackingCacheExtent = 900;

class _StackingCardState extends State<StackingCard> {
  final _boxKey = GlobalKey();
  ScrollPosition? _position;

  /// Last overshoot we could actually measure. Reused on a frame where the
  /// render object is transiently gone -- otherwise a parked row snapped from
  /// its lifted position down to zero and back on every list rebuild (an
  /// eat-toggle, a Firestore echo), which read as the row "refreshing".
  double _lastOvershoot = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position = Scrollable.maybeOf(context)?.position;
  }

  /// How far this row has travelled past the pile line, in pixels, or zero
  /// while it is still below it.
  double _overshoot() {
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return _lastOvershoot;
    // Global coordinates: this list runs full-bleed from the top of the
    // screen, so there is no intermediate frame of reference to resolve
    // against and one `localToGlobal` is the whole calculation.
    // A sliver can detach/re-parent this child between the checks above and
    // `localToGlobal` while its list is rebuilding (for example when Today's
    // Firestore stream replaces its entries). Flutter deliberately rejects a
    // transform through that transient tree. Stacking is decorative, so hold
    // the last measured position for that frame instead of snapping to zero
    // (or taking down the functional screen).
    try {
      final top = box.localToGlobal(Offset.zero).dy;
      if (top.isFinite) {
        _lastOvershoot = math.max(0, widget.stackTop - top);
      }
      return _lastOvershoot;
    } on FlutterError {
      return _lastOvershoot;
    } on AssertionError {
      return _lastOvershoot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    // No scroll to react to, or the user has asked for less movement: the
    // row is just a row.
    if (position == null || !MotionSettings.enabled(context)) {
      return KeyedSubtree(key: _boxKey, child: widget.child);
    }

    return SizedBox(
      key: _boxKey,
      child: AnimatedBuilder(
        animation: position,
        // Passed through untouched, so a scroll frame rebuilds the transform
        // and nothing else.
        child: widget.child,
        builder: (context, child) {
          final overshoot = _overshoot();
          if (overshoot <= 0) return child!;

          final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
          final rowExtent =
              math.max((box?.size.height ?? 0) + widget.spacing, 1);
          final depth =
              (overshoot / rowExtent).clamp(0.0, widget.maxVisible.toDouble());

          // `overshoot` alone pins the row exactly at the line; subtracting a
          // bounded term is what lifts each parked row a little further, and
          // what stops the pile growing once `depth` saturates.
          return Transform.translate(
            offset: Offset(0, overshoot - depth * widget.spacing),
            child: Transform.scale(
              scale: 1 - depth * .035,
              alignment: Alignment.topCenter,
              // Cards are glass, so a parked one would otherwise show the
              // text of the card behind it straight through and the pile
              // would read as one smeared row. An opaque plate, faded in over
              // the first few pixels of parking, is what makes the deck read
              // as separate cards -- and the geometric falloff sinks the ones
              // behind into shadow rather than leaving them legible.
              child: Opacity(
                opacity: math.pow(.5, depth).toDouble(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    // Opaque within the first row-edge of travel, so a card
                    // is solid by the time anything is behind it.
                    color: AppPalette.surface.withValues(
                        alpha: (overshoot / widget.spacing).clamp(0.0, 1.0)),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
