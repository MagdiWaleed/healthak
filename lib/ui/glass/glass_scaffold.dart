import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/profile/user_profile.dart';
import '../../service/settings_controller.dart';
import '../background/reactive_aurora.dart';
import '../theme/glass_tokens.dart';
import '../theme/mood_palette.dart';
import 'specular_border.dart';

class GlassScaffold extends StatefulWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final DayMood mood;

  const GlassScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.mood = DayMood.fresh,
  });

  @override
  State<GlassScaffold> createState() => _GlassScaffoldState();
}

class _GlassScaffoldState extends State<GlassScaffold> {
  final ValueNotifier<double> _specularAngle = ValueNotifier(-135);

  @override
  void dispose() {
    _specularAngle.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final next =
        -135 + notification.metrics.pixels / 100 * GlassTokens.refractionShift;
    if ((next - _specularAngle.value).abs() >= 2) {
      _specularAngle.value = next;
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
        // Balanced halves the drift rate rather than stopping it. Motion that
        // slows reads as calm; motion that stops reads as broken.
        speedScale: effective == GraphicsQuality.balanced ? 2.0 : 1.0,
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
