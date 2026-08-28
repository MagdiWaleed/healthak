import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mappers/profile_mapper.dart';
import '../data/repositories/profile_repository.dart';
import '../domain/profile/user_profile.dart';

const int kCurrentSchemaVersion = 2;

class PrefsService extends GetxService implements ProfileCache {
  late final SharedPreferences _prefs;

  Future<PrefsService> init() async {
    _prefs = await SharedPreferences.getInstance();
    final version = _prefs.getInt('schemaVersion') ?? 0;
    if (version < kCurrentSchemaVersion) {
      await _prefs.clear();
      await _prefs.setInt('schemaVersion', kCurrentSchemaVersion);
    }
    return this;
  }

  String? get uid => _prefs.getString('uid');

  AppSettings get cachedSettings =>
      cachedProfile?.settings ?? const AppSettings();

  UserProfile? get cachedProfile {
    final raw = _prefs.getString('profileJson');
    if (raw == null) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return ProfileMapper.fromJson(json,
          uid: json['uid'] as String? ?? uid ?? '');
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString('uid', profile.uid);
    await _prefs.setString(
        'profileJson', jsonEncode(ProfileMapper.toCacheJson(profile)));
    await _prefs.setString('cachedAt', DateTime.now().toIso8601String());
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(
      'settings',
      jsonEncode({
        'themeMode': settings.themeMode.name,
        'accent': settings.accent.name,
        'graphicsQuality': settings.graphicsQuality.name,
        'digits': settings.digits.name,
        'units': settings.units.name,
      }),
    );
  }

  @override
  Future<void> clearProfile() async {
    await _prefs.remove('uid');
    await _prefs.remove('profileJson');
    await _prefs.remove('cachedAt');
  }
}
