import 'package:get/get.dart';

import '../domain/profile/user_profile.dart';
import 'prefs_service.dart';

class SettingsController extends GetxController {
  final PrefsService _prefs;
  final settings = const AppSettings().obs;

  SettingsController(this._prefs);

  void load(AppSettings value) => settings.value = value;

  /// The probe re-runs every launch, so this moves the tier in either
  /// direction: a device mis-flagged as slow by one bad startup sample
  /// recovers on the next clean run instead of being pinned forever.
  Future<void> applyDetectedQuality(GraphicsQuality detected) async {
    if (detected == settings.value.graphicsQuality) return;
    await save(settings.value.copyWith(graphicsQuality: detected));
  }

  Future<void> save(AppSettings value) async {
    settings.value = value;
    await _prefs.saveSettings(value);
  }
}
