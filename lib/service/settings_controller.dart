import 'package:get/get.dart';

import '../domain/profile/user_profile.dart';
import 'prefs_service.dart';

class SettingsController extends GetxController {
  final PrefsService _prefs;
  final settings = const AppSettings().obs;

  SettingsController(this._prefs);

  void load(AppSettings value) => settings.value = value;

  Future<void> applyDetectedQuality(GraphicsQuality detected) async {
    final current = settings.value.graphicsQuality;
    if (detected.index <= current.index) return;
    await save(settings.value.copyWith(graphicsQuality: detected));
  }

  Future<void> save(AppSettings value) async {
    settings.value = value;
    await _prefs.saveSettings(value);
  }
}
