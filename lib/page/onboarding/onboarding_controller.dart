import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_routes.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/nutrition/energy.dart';
import '../../domain/profile/user_profile.dart';
import '../../service/auth_service.dart';

class OnboardingController extends GetxController {
  final AuthService _auth;
  final ProfileRepository _profiles;
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final birthYear = TextEditingController(text: '${DateTime.now().year - 25}');
  final height = TextEditingController(text: '170');
  final weight = TextEditingController(text: '70');
  final isLogin = true.obs;
  final collectingProfile = false.obs;
  final busy = false.obs;
  final error = RxnString();
  final sex = Sex.preferNotToSay.obs;
  final activity = ActivityLevel.moderate.obs;
  final goal = Goal.maintain.obs;
  final weeklyRate = .5.obs;
  final previewTargets = Rxn<NutritionTargets>();

  OnboardingController(this._auth, this._profiles);

  @override
  void onInit() {
    super.onInit();
    final user = _auth.currentUser;
    if (user != null) {
      collectingProfile.value = true;
      name.text = user.displayName ?? '';
      email.text = user.email ?? '';
    }
    for (final field in [birthYear, height, weight]) {
      field.addListener(recalculatePreview);
    }
    recalculatePreview();
  }

  NutritionTargets? _calculateTargets() {
    final year = int.tryParse(birthYear.text);
    final heightCm = double.tryParse(height.text);
    final weightKg = double.tryParse(weight.text);
    if (year == null ||
        heightCm == null ||
        weightKg == null ||
        heightCm <= 0 ||
        weightKg <= 0) {
      return null;
    }
    return NutritionTargets.compute(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: (DateTime.now().year - year).clamp(13, 100),
      sex: sex.value,
      activity: activity.value,
      goal: goal.value,
      weeklyRateKg: weeklyRate.value,
    );
  }

  void recalculatePreview() => previewTargets.value = _calculateTargets();

  Future<void> submitAuth() async {
    busy.value = true;
    error.value = null;
    try {
      if (isLogin.value) {
        final user =
            await _auth.signIn(email: email.text, password: password.text);
        final profile = await _profiles.get(user.uid);
        if (profile?.onboardingComplete == true) {
          unawaited(Get.offAllNamed(AppRoutes.home));
        } else {
          collectingProfile.value = true;
          name.text = user.displayName ?? name.text;
          recalculatePreview();
        }
      } else {
        await _auth.signUp(
            email: email.text, password: password.text, displayName: name.text);
        collectingProfile.value = true;
        recalculatePreview();
      }
    } on AuthFailure catch (failure) {
      error.value = failure.messageAr;
    } finally {
      busy.value = false;
    }
  }

  Future<void> saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final year = int.tryParse(birthYear.text);
    final heightCm = double.tryParse(height.text);
    final weightKg = double.tryParse(weight.text);
    if (year == null ||
        heightCm == null ||
        weightKg == null ||
        heightCm <= 0 ||
        weightKg <= 0) {
      error.value = 'أدخل سنة الميلاد والطول والوزن بشكل صحيح';
      return;
    }
    busy.value = true;
    final targets = _calculateTargets()!;
    previewTargets.value = targets;
    final now = DateTime.now();
    final profile = UserProfile(
      uid: user.uid,
      displayName: name.text.trim().isEmpty
          ? (user.displayName ?? '')
          : name.text.trim(),
      email: user.email ?? email.text.trim(),
      sex: sex.value,
      birthYear: year,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activity.value,
      goal: goal.value,
      weeklyRateKg: weeklyRate.value,
      targets: targets,
      onboardingComplete: true,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _profiles.save(profile);
      unawaited(Get.offAllNamed(AppRoutes.home));
    } catch (_) {
      error.value = 'تعذر حفظ الملف. حاول مرة أخرى.';
    } finally {
      busy.value = false;
    }
  }

  Future<void> resetPassword() async {
    try {
      await _auth.sendPasswordReset(email.text);
      Get.snackbar('تم الإرسال', 'تحقق من بريدك الإلكتروني');
    } on AuthFailure catch (failure) {
      error.value = failure.messageAr;
    }
  }

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    name.dispose();
    birthYear.dispose();
    height.dispose();
    weight.dispose();
    super.onClose();
  }
}
