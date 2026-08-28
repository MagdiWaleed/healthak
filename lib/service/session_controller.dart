import 'dart:async';

import 'package:get/get.dart';

import '../data/repositories/profile_repository.dart';
import '../domain/profile/user_profile.dart';
import 'auth_service.dart';
import 'prefs_service.dart';
import 'settings_controller.dart';

class SessionController extends GetxController {
  final AuthService _auth;
  final PrefsService _prefs;
  final ProfileRepository _profiles;
  final SettingsController _settings;
  final profile = Rxn<UserProfile>();
  final ready = false.obs;
  StreamSubscription<UserProfile?>? _profileSubscription;
  StreamSubscription<dynamic>? _authSubscription;

  SessionController({
    required AuthService auth,
    required PrefsService prefs,
    required ProfileRepository profiles,
    required SettingsController settings,
  })  : _auth = auth,
        _prefs = prefs,
        _profiles = profiles,
        _settings = settings;

  bool get isSignedIn => _auth.currentUser != null;
  bool get onboardingComplete => profile.value?.onboardingComplete == true;

  @override
  void onInit() {
    super.onInit();
    profile.value = _prefs.cachedProfile;
    _settings.load(_prefs.cachedSettings);
    _authSubscription = _auth.authState.listen((user) async {
      await _profileSubscription?.cancel();
      if (user == null) {
        profile.value = null;
        ready.value = true;
        return;
      }
      _profileSubscription = _profiles.watch(user.uid).listen((value) {
        profile.value = value;
        if (value != null) {
          _settings.load(value.settings);
          unawaited(_prefs.saveProfile(value));
        }
        ready.value = true;
      });
    });
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.onClose();
  }
}
