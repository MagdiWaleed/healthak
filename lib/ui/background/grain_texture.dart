import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A fixed film-grain overlay.
///
/// Grain is what makes a translucent surface read as *material* rather than as
/// flat opacity, and it hides the gradient banding that cheap panels show on
/// the aurora's long falloffs.
///
/// The noise is baked once into a small tiled image and drawn with a single
/// repeating [ui.ImageShader]. The previous implementation issued 750
/// individual `drawCircle` calls on every paint, which is a lot of work for
/// something that never changes.
class GrainTexture extends StatefulWidget {
  final double opacity;

  const GrainTexture({super.key, this.opacity = .045});

  @override
  State<GrainTexture> createState() => _GrainTextureState();
}

class _GrainTextureState extends State<GrainTexture> {
  static const _tileSize = 128;

  /// Shared across every instance and every route -- the tile is
  /// resolution-independent and identical everywhere.
  static ui.Image? _tile;
  static Future<ui.Image>? _pending;

  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    final ready = _tile;
    if (ready != null) {
      _image = ready;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final image = await (_pending ??= _buildTile());
    _tile = image;
    if (mounted) setState(() => _image = image);
  }

  static Future<ui.Image> _buildTile() {
    // A fixed seed keeps the grain identical between launches, so the texture
    // never appears to "resample" when a route rebuilds.
    final random = math.Random(0x5EED);
    final pixels = Uint8List(_tileSize * _tileSize * 4);

    for (var i = 0; i < _tileSize * _tileSize; i++) {
      // Monochrome noise carried entirely in the alpha channel. Premultiplied
      // rgba8888 means the colour channels must be scaled by alpha.
      final a = (random.nextDouble() * 255).round();
      final o = i * 4;
      pixels[o] = a;
      pixels[o + 1] = a;
      pixels[o + 2] = a;
      pixels[o + 3] = a;
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      _tileSize,
      _tileSize,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    // Absent for the first frame or two. Grain is subtle enough that its
    // arrival is imperceptible.
    if (image == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GrainPainter(
            image: image,
            opacity: widget.opacity,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final ui.Image image;
  final double opacity;
  final double devicePixelRatio;

  const _GrainPainter({
    required this.image,
    required this.opacity,
    required this.devicePixelRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the tile at one texel per physical pixel. Left at logical scale the
    // grain smears into visible blotches on a 3x screen.
    final scale = 1 / devicePixelRatio;
    final matrix = Matrix4.identity()..scaleByDouble(scale, scale, 1, 1);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.ImageShader(
          image,
          TileMode.repeated,
          TileMode.repeated,
          matrix.storage,
        )
        ..color = Colors.white.withValues(alpha: opacity)
        ..blendMode = BlendMode.softLight,
    );
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) =>
      old.image != image ||
      old.opacity != opacity ||
      old.devicePixelRatio != devicePixelRatio;
}
