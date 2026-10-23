import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../domain/profile/user_profile.dart';

/// Samples real raster-thread frame times once the first screen has settled
/// and picks a graphics tier from the p95.
///
/// Deliberately not run during startup: the first frames after launch are the
/// jankiest the app ever renders, and sampling them misreported a capable
/// device as slow -- which, combined with a persisted one-way downgrade,
/// pinned it to reduced quality permanently. The probe now re-runs every
/// launch and the result is applied in either direction, so one bad sample
/// self-corrects.
class PerformanceProbe extends GetxService {
  static const int sampleSize = 60;

  /// Frames discarded before sampling begins -- covers the first route's
  /// build/layout spike even when the probe starts a few seconds in.
  static const int warmupFrames = 20;

  static const Duration _window = Duration(seconds: 8);

  final _rasterMicros = <int>[];
  int _warmup = warmupFrames;
  Completer<GraphicsQuality>? _completer;

  Future<GraphicsQuality> sample() {
    if (_completer != null) return _completer!.future;
    _completer = Completer<GraphicsQuality>();
    _warmup = warmupFrames;
    _rasterMicros.clear();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    return _completer!.future.timeout(
      _window,
      onTimeout: () {
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
        _completer = null;
        // Whatever we did see still beats a blind guess. Too few frames to
        // trust means the device was mostly idle -- not a slow device -- so
        // assume the top tier rather than punishing it.
        final result = _rasterMicros.length >= 15
            ? _classify(_p95(_rasterMicros))
            : GraphicsQuality.high;
        _rasterMicros.clear();
        return result;
      },
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      if (_warmup > 0) {
        _warmup--;
        continue;
      }
      _rasterMicros.add(timing.rasterDuration.inMicroseconds);
    }
    if (_rasterMicros.length < sampleSize) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    final completer = _completer;
    _completer = null;
    completer?.complete(_classify(_p95(_rasterMicros)));
    _rasterMicros.clear();
  }

  static int _p95(List<int> micros) {
    final sorted = [...micros]..sort();
    return sorted[((sorted.length - 1) * .95).round()];
  }

  static GraphicsQuality _classify(int p95Micros) => p95Micros > 16000
      ? GraphicsQuality.low
      : p95Micros > 12000
          ? GraphicsQuality.balanced
          : GraphicsQuality.high;
}
