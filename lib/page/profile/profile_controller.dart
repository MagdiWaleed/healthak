import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/profile_repository.dart';
import '../../domain/nutrition/energy.dart';
import '../../domain/profile/user_profile.dart';
import '../../service/auth_service.dart';
import '../../service/session_controller.dart';

/// Backs the profile edit screen: body stats, activity, and goal, with a
/// live before/after preview of what changing them does to the day's target.
///
/// Replaces `my_informations_screen.dart` (the Arabic app bar typo
/// "معلواتي") and `MyCriteriaScreen`'s two `RadioListTile`s, which hardcoded
/// `groupValue: true` with an argument-ignoring `onChanged` -- abused as
/// toggles rather than an actual radio group, which is why they needed a
/// rewrite rather than a straight deprecation migration.
class ProfileController extends GetxController {
  final ProfileRepository _profiles;
  final AuthService _auth;
  final SessionController _session;

  ProfileController({
    ProfileRepository? profiles,
    AuthService? auth,
    SessionController? session,
  })  : _profiles = profiles ?? ProfileRepository(),
        _auth = auth ?? Get.find<AuthService>(),
        _session = session ?? Get.find<SessionController>();

  final height = TextEditingController();
  final weight = TextEditingController();
  final birthYear = TextEditingController();

  // Mirrors of the three text controllers above, as `.obs` values. The app's
  // convention is Rx/Obx, not GetBuilder's `update()` -- these are what let
  // the live before/after preview react to typing without stepping outside
  // that convention.
  final _heightText = ''.obs;
  final _weightText = ''.obs;
  final _birthYearText = ''.obs;

  final sex = Sex.male.obs;
  final activity = ActivityLevel.moderate.obs;
  final goal = Goal.maintain.obs;
  final weeklyRate = .5.obs;

  final saving = false.obs;
  final deleting = false.obs;
  final error = RxnString();

  UserProfile? get _current => _session.profile.value;

  @override
  void onInit() {
    super.onInit();
    final profile = _current;
    if (profile == null) return;
    height.text = profile.heightCm.round().toString();
    weight.text = profile.weightKg.round().toString();
    birthYear.text = profile.birthYear.toString();
    sex.value = profile.sex;
    activity.value = profile.activityLevel;
    goal.value = profile.goal;
    weeklyRate.value = profile.weeklyRateKg;

    _heightText.value = height.text;
    _weightText.value = weight.text;
    _birthYearText.value = birthYear.text;
    height.addListener(() => _heightText.value = height.text);
    weight.addListener(() => _weightText.value = weight.text);
    birthYear.addListener(() => _birthYearText.value = birthYear.text);
  }

  @override
  void onClose() {
    height.dispose();
    weight.dispose();
    birthYear.dispose();
    super.onClose();
  }

  /// Reads the `.obs` text mirrors, not the `TextEditingController`s
  /// directly, so an `Obx` wrapping this in the screen reacts to typing.
  NutritionTargets? get previewTargets {
    final h = double.tryParse(_heightText.value);
    final w = double.tryParse(_weightText.value);
    final y = int.tryParse(_birthYearText.value);
    if (h == null || w == null || y == null || h <= 0 || w <= 0) return null;
    return NutritionTargets.compute(
      weightKg: w,
      heightCm: h,
      ageYears: DateTime.now().year - y,
      sex: sex.value,
      activity: activity.value,
      goal: goal.value,
      weeklyRateKg: weeklyRate.value,
    );
  }

  NutritionTargets? get currentTargets => _current?.targets;

  /// The rate expressed the way the user asked to set it: kcal cut (or
  /// added) per day. Stored as a weekly kilogram rate because that is what
  /// [NutritionTargets.compute] takes; this is the same number in the other
  /// unit, not a second source of truth.
  double get dailyDelta => dailyDeltaForWeeklyRate(weeklyRate.value);

  set dailyDelta(double kcalPerDay) =>
      weeklyRate.value = weeklyRateForDailyDelta(kcalPerDay);

  /// Maintenance for the numbers currently typed in, or null while they are
  /// incomplete.
  double? get previewMaintenance {
    final h = double.tryParse(_heightText.value);
    final w = double.tryParse(_weightText.value);
    final y = int.tryParse(_birthYearText.value);
    if (h == null || w == null || y == null || h <= 0 || w <= 0) return null;
    return tdee(
      bmr: bmrMifflinStJeor(
        weightKg: w,
        heightCm: h,
        ageYears: DateTime.now().year - y,
        sex: sex.value,
      ),
      activity: activity.value,
    );
  }

  /// What the previewed target actually delivers per week, which is not
  /// always what was requested -- `dailyTarget` clamps at the energy floor,
  /// so an aggressive cut silently becomes a gentler one. Positive is loss.
  double? get effectiveWeeklyKg {
    final maintenance = previewMaintenance;
    final preview = previewTargets;
    if (maintenance == null || preview == null) return null;
    return (maintenance - preview.kcal) * 7 / kKcalPerKg;
  }

  /// True when the energy floor cut the requested rate down. Worth saying out
  /// loud rather than showing a projection the target cannot reach.
  bool get rateWasClamped {
    final effective = effectiveWeeklyKg;
    if (effective == null || goal.value == Goal.maintain) return false;
    return (effective.abs() - weeklyRate.value).abs() > 0.02;
  }

  /// A transient profile lets presentational widgets reuse the one
  /// profile-shaped input they need while this edit form is still unsaved.
  UserProfile? get previewProfile {
    final profile = _current;
    final targets = previewTargets;
    if (profile == null || targets == null) return null;
    return profile.copyWith(
      heightCm: double.parse(height.text),
      weightKg: double.parse(weight.text),
      birthYear: int.parse(birthYear.text),
      sex: sex.value,
      activityLevel: activity.value,
      goal: goal.value,
      weeklyRateKg: weeklyRate.value,
      targets: targets,
    );
  }

  /// The kcal delta a save would produce, for the before/after banner.
  double? get kcalDelta {
    final preview = previewTargets;
    final current = currentTargets;
    if (preview == null || current == null) return null;
    return preview.kcal - current.kcal;
  }

  Future<bool> save() async {
    final profile = _current;
    final preview = previewTargets;
    if (profile == null || preview == null) return false;

    saving.value = true;
    error.value = null;
    try {
      await _profiles.save(profile.copyWith(
        heightCm: double.parse(height.text),
        weightKg: double.parse(weight.text),
        birthYear: int.parse(birthYear.text),
        sex: sex.value,
        activityLevel: activity.value,
        goal: goal.value,
        weeklyRateKg: weeklyRate.value,
        targets: preview,
      ));
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      saving.value = false;
    }
  }

  /// Deletes the Firestore profile and the Firebase Auth account together --
  /// see [ProfileRepository.delete]'s doc on why neither is left orphaned.
  /// Called only after the screen's typed confirmation.
  Future<bool> deleteAccount() async {
    final profile = _current;
    if (profile == null) return false;

    deleting.value = true;
    error.value = null;
    try {
      await _profiles.delete(profile.uid);
      await _auth.deleteAccount();
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      deleting.value = false;
    }
  }
}
