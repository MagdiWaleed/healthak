import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/profile/user_profile.dart';
import '../../service/settings_controller.dart';
import '../background/aurora_background.dart';

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const GlassScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  Widget build(BuildContext context) {
    Widget background(GraphicsQuality quality) {
      final media = MediaQuery.of(context);
      final reduceMotion =
          media.disableAnimations || media.accessibleNavigation;
      final effective = reduceMotion ? GraphicsQuality.low : quality;
      return AuroraBackground(
        key: ValueKey(effective),
        animate: effective != GraphicsQuality.low,
        showGrain: effective != GraphicsQuality.low,
        // Balanced halves the drift rate rather than stopping it. Motion that
        // slows reads as calm; motion that stops reads as broken.
        speedScale: effective == GraphicsQuality.balanced ? 2.0 : 1.0,
        child: SafeArea(child: body),
      );
    }

    final backgroundBody = Get.isRegistered<SettingsController>()
        ? Obx(() => background(
            Get.find<SettingsController>().settings.value.graphicsQuality))
        : background(GraphicsQuality.high);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: backgroundBody,
    );
  }
}
