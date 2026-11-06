import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:get/get.dart';

import '../../data/repositories/body_weight_repository.dart';
import '../../data/repositories/day_repository.dart';
import '../../data/repositories/training_day_repository.dart';
import '../../domain/body/body_weight.dart';
import '../../domain/day/day_log.dart';
import '../../domain/progress/streaks.dart';
import '../../domain/training/training_day.dart';
import '../../service/session_controller.dart';

class ProgressController extends GetxController {
  ProgressController({
    required this.uid,
    DayRepository? days,
    TrainingDayRepository? trainingDays,
    BodyWeightRepository? weights,
    SessionController? session,
    DateTime Function()? clock,
  })  : _days = days ?? DayRepository(uid: uid),
        _trainingDays = trainingDays ?? TrainingDayRepository(uid: uid),
        _weights = weights ?? BodyWeightRepository(uid: uid),
        _session = session ?? Get.find<SessionController>(),
        _clock = clock ?? DateTime.now;

  final String uid;
  final DayRepository _days;
  final TrainingDayRepository _trainingDays;
  final BodyWeightRepository _weights;
  final SessionController _session;
  final DateTime Function() _clock;
  final rangeDays = 30.obs;
  final days = <DayLog>[].obs;
  final trainingDays = <TrainingDay>[].obs;
  final weights = <BodyWeightEntry>[].obs;
  final latestWeights = <BodyWeightEntry>[].obs;
  final error = RxnString();
  final loading = true.obs;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  double? get goalKg => _session.profile.value?.goalWeightKg;

  List<BodyWeightEntry> get visibleWeights {
    final from = DayLog.keyFor(
        DateTime(today.year, today.month, today.day - rangeDays.value + 1));
    return (weights.where((e) => e.dateKey.compareTo(from) >= 0).toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey)));
  }

  WeightTrend get trend => WeightTrend(visibleWeights);

  double? get rangeDeltaKg {
    final values = trend.ema;
    return values.length < 2 ? null : values.last - values.first;
  }

  StreakResult get calorieStreak => computeStreak(
      days.where(isCalorieHit).map((e) => e.dateKey).toSet(), today);
  StreakResult get trainingStreak => computeStreak(
      trainingDays.where((e) => e.isComplete).map((e) => e.dateKey).toSet(),
      today);
  StreakResult get weighInStreak =>
      computeStreak(weights.map((e) => e.dateKey).toSet(), today);

  DateTime get recapStart => DateTime(today.year, today.month, today.day - 6);
  List<DayLog> get recapDays {
    final from = DayLog.keyFor(recapStart);
    return days.where((e) => e.dateKey.compareTo(from) >= 0).toList();
  }

  WeeklyRecap get recap => WeeklyRecap.fromWindow(
        start: recapStart,
        calories: recapDays
            .where((e) => e.consumedKcal > 0)
            .map((e) => DailyKcal(e.dateKey, e.consumedKcal)),
        trainingDays: trainingDays,
        weights: weights,
      );

  double? get recapTargetKcal {
    final logged = recapDays.where((e) => e.consumedKcal > 0).toList();
    if (logged.isEmpty) return null;
    return logged.fold<double>(0, (sum, e) => sum + e.targets.kcal) /
        logged.length;
  }

  void selectRange(int value) => rangeDays.value = value;

  @override
  void onInit() {
    super.onInit();
    final from = DateTime(today.year, today.month, today.day - 89);
    void failed(Object e) {
      // Surfaced in `flutter run` / CLI smoke logs; the UI shows a generic
      // message. Swallowing it hid a real Firestore failure on device.
      debugPrint('ProgressController load failed: $e');
      error.value = 'load';
      loading.value = false;
    }

    _subscriptions.add(_days.watchRange(from, today).listen((value) {
      days.assignAll(value);
      loading.value = false;
    }, onError: failed));
    _subscriptions.add(_trainingDays
        .watchRange(from, today)
        .listen(trainingDays.assignAll, onError: failed));
    _subscriptions.add(_weights
        .watchRange(from, today)
        .listen(weights.assignAll, onError: failed));
    _subscriptions.add(_weights
        .watchLatest(10)
        .listen(latestWeights.assignAll, onError: failed));
  }

  Future<void> deleteWeight(BodyWeightEntry entry) =>
      _weights.delete(entry.dateKey);

  @override
  void onClose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.onClose();
  }
}
