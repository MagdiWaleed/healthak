import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../theme/motion_settings.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  const ShimmerBox(
      {this.width, this.height = 20, this.borderRadius, super.key});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppPalette.raised,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
    );
    return MotionSettings.enabled(context)
        ? box.animate(onPlay: (controller) => controller.repeat()).shimmer(
            duration: const Duration(milliseconds: 1200),
            color: AppPalette.muted.withValues(alpha: .18))
        : box;
  }
}
