import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../domain/profile/user_profile.dart';

class PerformanceProbe extends GetxService {
  static const int sampleSize = 90;
  final _rasterMicros = <int>[];
  Completer<GraphicsQuality>? _completer;

  Future<GraphicsQuality> sample() {
    if (_completer != null) return _completer!.future;
    _completer = Completer<GraphicsQuality>();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    return _completer!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
        _completer = null;
        _rasterMicros.clear();
        return GraphicsQuality.balanced;
      },
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    _rasterMicros
        .addAll(timings.map((timing) => timing.rasterDuration.inMicroseconds));
    if (_rasterMicros.length < sampleSize) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _rasterMicros.sort();
    final p95 = _rasterMicros[((_rasterMicros.length - 1) * .95).round()];
    final completer = _completer;
    _completer = null;
    completer?.complete(
      p95 > 16000
          ? GraphicsQuality.low
          : p95 > 12000
              ? GraphicsQuality.balanced
              : GraphicsQuality.high,
    );
    _rasterMicros.clear();
  }
}
