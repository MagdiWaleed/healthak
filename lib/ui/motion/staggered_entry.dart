import 'package:flutter/material.dart';

/// Fades, lifts and settles a list row into place, offset by its position.
///
/// One controller drives all three transforms. The previous version nested
/// three implicit `AnimatedX` widgets, which meant three controllers per row --
/// twenty-four for a list of eight.
class StaggeredEntry extends StatefulWidget {
  final int index;
  final Widget child;

  /// Rows past this index skip the delay and animate immediately, so a long
  /// list does not take seconds to finish arriving.
  final int maxStaggered;

  final Duration step;
  final Duration duration;

  /// Pass `false` once a list has finished its first load.
  ///
  /// `ListView.builder` recycles elements, so a row scrolled off and back on
  /// runs `initState` again and replays its entry. Gating on a first-load flag
  /// is what stops rows re-animating under the user's thumb.
  final bool enabled;

  /// One-shot replay guard. When both are set, this row animates only the
  /// first time [replayKey] is seen in [replayGuard]; a later mount with a key
  /// already in the set renders in its final state instead of sliding again.
  ///
  /// Registration is synchronous with `initState`, so it is immune to the
  /// relayout/rebuild churn a sliver list goes through when an item is added
  /// -- which a post-frame "seen" set was not, and which was re-animating the
  /// section nearest the pinned header on every add.
  final Object? replayKey;
  final Set<Object>? replayGuard;

  const StaggeredEntry({
    required this.index,
    required this.child,
    super.key,
    this.maxStaggered = 8,
    this.step = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 420),
    this.enabled = true,
    this.replayKey,
    this.replayGuard,
  });

  @override
  State<StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final bool _animate = _resolveAnimate();

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    // Starting completed means a settled entry costs nothing and renders in
    // its final state on the very first frame.
    value: _animate ? 0 : 1,
  );

  late final Animation<double> _eased = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final Animation<double> _scale = _eased.drive(
    Tween(begin: .97, end: 1.0),
  );

  bool _resolveAnimate() {
    if (!widget.enabled) return false;
    final key = widget.replayKey;
    final guard = widget.replayGuard;
    if (key == null || guard == null) return true;
    // `add` returns false when the key was already present -- i.e. this row
    // has animated before and should not again.
    return guard.add(key);
  }

  @override
  void initState() {
    super.initState();
    if (!_animate) return;

    final slot = widget.index.clamp(0, widget.maxStaggered - 1);
    if (slot == 0) {
      _controller.forward();
      return;
    }
    Future<void>.delayed(widget.step * slot, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Start" is a physical right edge in Arabic and physical left in LTR.
    // Resolve it here (not in a stored Offset) so test and locale changes are
    // mirrored by the same entry choreography.
    final fromStart =
        Directionality.of(context) == TextDirection.rtl ? .06 : -.06;
    return FadeTransition(
      opacity: _eased,
      child: AnimatedBuilder(
        animation: _eased,
        child: ScaleTransition(scale: _scale, child: widget.child),
        builder: (_, child) => Transform.translate(
          offset: Offset(
              fromStart * (1 - _eased.value) * 100, (1 - _eased.value) * 4),
          child: Transform.rotate(
            angle: (1 - _eased.value) * -.02618,
            child: child,
          ),
        ),
      ),
    );
  }
}
