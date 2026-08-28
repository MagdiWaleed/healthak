import 'dart:async';

import 'package:get/get.dart';

import '../../app/app_routes.dart';
import '../../data/repositories/profile_repository.dart';
import '../../service/auth_service.dart';
import '../../service/prefs_service.dart';

class SplashController extends GetxController {
  final AuthService _auth;
  final PrefsService _prefs;
  final ProfileRepository _profiles;
  final error = RxnString();

  SplashController(this._auth, this._prefs, this._profiles);

  @override
  void onReady() {
    super.onReady();
    unawaited(resolve());
  }

  Future<void> resolve() async {
    error.value = null;
    final user = _auth.currentUser;
    if (user == null) {
      unawaited(Get.offAllNamed(AppRoutes.guest));
      return;
    }
    final cached = _prefs.cachedProfile;
    if (cached?.uid == user.uid && cached?.onboardingComplete == true) {
      unawaited(Get.offAllNamed(AppRoutes.home));
      return;
    }
    try {
      final profile = await _profiles.get(user.uid);
      if (profile != null) await _prefs.saveProfile(profile);
      unawaited(Get.offAllNamed(profile?.onboardingComplete == true
          ? AppRoutes.home
          : AppRoutes.onboarding));
    } catch (_) {
      error.value = 'تعذر تحميل الحساب. تحقق من الاتصال ثم حاول مرة أخرى.';
    }
  }
}
