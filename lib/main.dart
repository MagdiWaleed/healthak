import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app/app_pages.dart';
import 'app/app_routes.dart';
import 'data/firestore_refs.dart';
import 'data/repositories/profile_repository.dart';
import 'firebase_options.dart';
import 'l10n/app_strings.dart';
import 'service/auth_service.dart';
import 'service/performance_probe.dart';
import 'service/prefs_service.dart';
import 'service/session_controller.dart';
import 'service/settings_controller.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  final prefs =
      await Get.putAsync(() => PrefsService().init(), permanent: true);
  final auth = Get.put(AuthService(), permanent: true);
  final profiles = Get.put(
    ProfileRepository(refs: FirestoreRefs(), cache: prefs),
    permanent: true,
  );
  final settings = Get.put(SettingsController(prefs), permanent: true);
  settings.load(prefs.cachedSettings);
  final performance = Get.put(PerformanceProbe(), permanent: true);
  Get.put(
    SessionController(
      auth: auth,
      prefs: prefs,
      profiles: profiles,
      settings: settings,
    ),
    permanent: true,
  );

  runApp(const HealthakApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(performance.sample().then(settings.applyDetectedQuality));
  });
}

class HealthakApp extends StatelessWidget {
  const HealthakApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        fallbackLocale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
      );
}
