import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../l10n/app_strings.dart';
import '../../ui/background/aurora_background.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/theme/app_colors.dart';
import 'splash_controller.dart';

class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AuroraBackground(
          child: Center(
            child: Obx(() {
              final message = controller.error.value;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: message == null
                    ? const _Brand(key: ValueKey('brand'))
                    : _SplashError(
                        key: const ValueKey('error'),
                        message: message,
                        onRetry: controller.resolve,
                      ),
              );
            }),
          ),
        ),
      );
}

/// Mark, name, and a ring-shaped progress indicator built from the same
/// vocabulary as [CalorieRing] -- a swept gradient arc, not the stock
/// [CircularProgressIndicator] -- so the very first frame already looks like
/// this app rather than any other Flutter app.
class _Brand extends StatefulWidget {
  const _Brand({super.key});

  @override
  State<_Brand> createState() => _BrandState();
}

class _BrandState extends State<_Brand> with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _entrance.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entrance = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutBack,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: entrance.drive(Tween(begin: .7, end: 1.0)),
          child: FadeTransition(
            opacity: _entrance,
            child: AnimatedBuilder(
              animation: _spin,
              builder: (context, child) => CustomPaint(
                painter: _MarkPainter(_spin.value),
                child: child,
              ),
              child: const SizedBox.square(
                dimension: 92,
                child: Center(
                  child: Icon(Icons.eco_rounded,
                      size: 40, color: AppPalette.text),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        FadeTransition(
          opacity: CurvedAnimation(
            parent: _entrance,
            curve: const Interval(.35, 1.0, curve: Curves.easeOut),
          ),
          child: const Text(
            AppStrings.appName,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
              color: AppPalette.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  final double t;
  const _MarkPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * .06;
    final arc = rect.deflate(stroke);

    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: .10),
    );

    final shader = const SweepGradient(
      colors: [
        AppPalette.emerald,
        AppPalette.mint,
        AppPalette.amber,
        AppPalette.violet,
        AppPalette.emerald,
      ],
    ).createShader(rect);

    // A 3/4 arc rotating continuously reads as "working" without the visual
    // noise of a full ring chasing its own tail.
    canvas.drawArc(
      arc,
      t * math.pi * 2,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.t != t;
}

class _SplashError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SplashError({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: AppPalette.amber),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            GlassButton(label: AppStrings.retry, onPressed: onRetry),
          ],
        ),
      );
}
