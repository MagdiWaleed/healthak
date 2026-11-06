import 'package:get/get.dart';
import '../data/repositories/body_weight_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../domain/body/body_weight.dart';
import '../domain/day/day_log.dart';
import '../domain/nutrition/energy.dart';
import '../domain/profile/user_profile.dart';
import 'session_controller.dart';

/// Pure decision used before persisting a new weigh-in.
UserProfile? profileAfterWeighIn({
  required UserProfile? profile,
  required double kg,
  required String dateKey,
  required String? latestDateKey,
  required DateTime now,
}) {
  if (profile == null ||
      (latestDateKey != null && dateKey.compareTo(latestDateKey) < 0)) {
    return null;
  }
  final targets = profile.targets.mode == TargetMode.manual
      ? profile.targets
      : NutritionTargets.compute(
          weightKg: kg,
          heightCm: profile.heightCm,
          ageYears: now.year - profile.birthYear,
          sex: profile.sex,
          activity: profile.activityLevel,
          goal: profile.goal,
          weeklyRateKg: profile.weeklyRateKg,
        );
  return profile.copyWith(weightKg: kg, targets: targets, updatedAt: now);
}

class WeighInService {
  final BodyWeightRepository weights;
  final ProfileRepository profiles;
  final SessionController session;
  final DateTime Function() clock;

  WeighInService({
    required this.weights,
    required this.profiles,
    SessionController? session,
    DateTime Function()? clock,
  })  : session = session ?? Get.find<SessionController>(),
        clock = clock ?? DateTime.now;

  Future<void> logWeight({required DateTime date, required double kg}) async {
    if (!kg.isFinite || kg < 25 || kg > 350) {
      throw ArgumentError.value(kg, 'kg');
    }
    final dateKey = DayLog.keyFor(date);
    final now = clock();
    final latest = await weights.getLatest();
    final existing = await weights.get(date);
    await weights.save(
      BodyWeightEntry(
        dateKey: dateKey,
        date: DateTime(date.year, date.month, date.day),
        kg: kg,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    final updated = profileAfterWeighIn(
      profile: session.profile.value,
      kg: kg,
      dateKey: dateKey,
      latestDateKey: latest?.dateKey,
      now: now,
    );
    if (updated != null) {
      await profiles.save(updated);
      session.profile.value = updated;
    }
  }
}
