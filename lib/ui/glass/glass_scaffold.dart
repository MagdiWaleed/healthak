import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/profile/user_profile.dart';
import '../../service/settings_controller.dart';
import '../background/reactive_aurora.dart';
import '../theme/glass_tokens.dart';
import '../theme/mood_palette.dart';
import '../theme/motion_settings.dart';
import 'specular_border.dart';

class GlassScaffold extends StatefulWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final DayMood mood;

  /// Changes when an already-mounted scaffold reveals a different page, such
  /// as a tab inside an `IndexedStack`. New routes get the same entrance glint
  /// automatically from `initState`; this key covers navigation that reuses
  /// the existing scaffold state.
  final Object? lightEventKey;

  const GlassScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.mood = DayMood.fresh,
    this.lightEventKey,
  });

  @override
  State<GlassScaffold> createState() => _GlassScaffoldState();
}

class _GlassScaffoldState extends State<GlassScaffold>
    with SingleTickerProviderStateMixin {
  static const _restingAngle = -135.0;
  // This is an ambient shader sweep, not a transition that blocks input. It
  // deliberately far outlives the route transition so the light can be
  // followed slowly around the rounded edge instead of reading as a flash.
  // Near-constant speed with a soft deceleration at the very end; the 2 degree
  // publish gate below naturally thins this to ~30fps at this duration.
  static const _arrivalDuration = Duration(milliseconds: 3250);
  static const _arrivalCurve = Curves.easeOut;

  final ValueNotifier<double> _specularAngle = ValueNotifier(-135);
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: _arrivalDuration,
  )..addListener(() => _publishSpecularAngle());
  double _scrollAngle = _restingAngle;

  // Scroll drives the specular angle, and every angle change repaints every
  // visible glass card's border. At 60fps that is a lot of redundant stroke
  // work for a highlight nobody tracks pixel-by-pixel, so scroll-driven
  // publishes are rate-limited to ~17fps -- with an immediate publish when a
  // gesture starts, settles, or jumps far, so the ends of a fling still land.
  static const _scrollPublishGap = Duration(milliseconds: 58);
  DateTime _lastScrollPublish = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastScrollAnglePublished = _restingAngle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playArrivalGlint();
    });
  }

  @override
  void didUpdateWidget(covariant GlassScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lightEventKey != oldWidget.lightEventKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playArrivalGlint();
      });
    }
  }

  void _playArrivalGlint() {
    if (!MotionSettings.enabled(context)) {
      _arrival.stop();
      _arrival.value = 0;
      _publishSpecularAngle(force: true);
      return;
    }

    // A quick second navigation joins the sweep already in flight. Restarting
    // it would visibly snap the highlight backward; stacking controllers
    // would make every card repaint more than once per frame.
    if (_arrival.isAnimating) return;
    if (_arrival.isCompleted) _arrival.value = 0;
    _arrival.forward();
  }

  void _publishSpecularAngle({bool force = false, bool coarse = false}) {
    final orbit = _arrivalCurve.transform(_arrival.value) * 360;
    final next = _scrollAngle + orbit;
    // The arrival glint wants every small step; a scroll shimmer does not.
    final threshold = coarse ? 5.0 : 2.0;
    if (force || (next - _specularAngle.value).abs() >= threshold) {
      _specularAngle.value = next;
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    _specularAngle.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (!MotionSettings.enabled(context)) return false;
    _scrollAngle = _restingAngle +
        notification.metrics.pixels /
            100 *
            GlassTokens.refractionShift *
            GlassTokens.refractionAngleGain;

    final now = DateTime.now();
    final atGestureEdge = notification is ScrollStartNotification ||
        notification is ScrollEndNotification;
    final jumpedFar =
        (_scrollAngle - _lastScrollAnglePublished).abs() >= 9;
    if (atGestureEdge ||
        jumpedFar ||
        now.difference(_lastScrollPublish) >= _scrollPublishGap) {
      _lastScrollPublish = now;
      _lastScrollAnglePublished = _scrollAngle;
      _publishSpecularAngle(coarse: true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Widget background(GraphicsQuality quality) {
      final media = MediaQuery.of(context);
      final reduceMotion =
          media.disableAnimations || media.accessibleNavigation;
      final effective = reduceMotion ? GraphicsQuality.low : quality;
      return ReactiveAurora(
        key: ValueKey((effective, widget.mood)),
        mood: widget.mood,
        animate: effective != GraphicsQuality.low,
        showGrain: effective != GraphicsQuality.low,
        // Balanced slows the drift and drops its repaint rate rather than
        // stopping it. Motion that slows reads as calm; motion that stops
        // reads as broken.
        speedScale: effective == GraphicsQuality.balanced ? 2.0 : 1.0,
        maxFps: effective == GraphicsQuality.balanced ? 20 : 30,
        child: SafeArea(child: widget.body),
      );
    }

    final backgroundBody = Get.isRegistered<SettingsController>()
        ? Obx(() => background(
            Get.find<SettingsController>().settings.value.graphicsQuality))
        : background(GraphicsQuality.high);

    return SpecularScope(
      angle: _specularAngle,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: widget.appBar,
          bottomNavigationBar: widget.bottomNavigationBar,
          floatingActionButton: widget.floatingActionButton,
          floatingActionButtonLocation: widget.floatingActionButtonLocation,
          body: backgroundBody,
        ),
      ),
    );
  }
}
