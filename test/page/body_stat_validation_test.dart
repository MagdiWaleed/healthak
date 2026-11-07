import 'package:diet_app2/data/repositories/profile_repository.dart';
import 'package:diet_app2/domain/nutrition/energy.dart';
import 'package:diet_app2/domain/profile/body_stats.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/l10n/app_strings.dart';
import 'package:diet_app2/page/onboarding/onboarding_controller.dart';
import 'package:diet_app2/page/onboarding/onboarding_screen.dart';
import 'package:diet_app2/page/profile/profile_controller.dart';
import 'package:diet_app2/service/auth_service.dart';
import 'package:diet_app2/service/session_controller.dart';
import 'package:diet_app2/ui/format/body_stat_input.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _User implements User {
  @override
  String get uid => 'u';
  @override
  String? get email => 'u@example.com';
  @override
  String? get displayName => 'User';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements AuthService {
  @override
  User? get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements ProfileRepository {
  int saves = 0;
  @override
  Future<void> save(UserProfile profile) async {
    saves++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements SessionController {
  @override
  final profile = Rxn<UserProfile>();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Profiles profiles;
  setUp(() {
    profiles = _Profiles();
  });
  tearDown(Get.reset);

  test('onboarding rejects appended height and parses Arabic digits', () async {
    final c = OnboardingController(_Auth(), profiles)..onInit();
    c.height.text = '170178';
    expect(c.previewTargets.value, isNull);
    await c.saveProfile();
    expect(profiles.saves, 0);
    expect(c.fieldError.value, BodyStatsError.height);
    expect(c.error.value, AppStrings.invalidHeight);
    c.height.text = '١٧٨';
    c.weight.text = '٧٢٫٥';
    expect(c.previewTargets.value, isNotNull);
    c.onClose();
  });

  test('profile rejects appended height and hides invalid previews', () async {
    final session = _Session();
    session.profile.value = UserProfile(
      uid: 'u',
      displayName: 'User',
      email: 'u@example.com',
      sex: Sex.male,
      birthYear: 2000,
      heightCm: 170,
      weightKg: 70,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.maintain,
      weeklyRateKg: .5,
      targets: NutritionTargets.compute(
          weightKg: 70,
          heightCm: 170,
          ageYears: 26,
          sex: Sex.male,
          activity: ActivityLevel.moderate,
          goal: Goal.maintain,
          weeklyRateKg: .5),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final c =
        ProfileController(profiles: profiles, auth: _Auth(), session: session)
          ..onInit();
    c.height.text = '170178';
    expect(c.previewTargets, isNull);
    expect(c.previewMaintenance, isNull);
    expect(await c.save(), isFalse);
    expect(profiles.saves, 0);
    expect(c.fieldError.value, BodyStatsError.height);
    c.height.text = '١٧٨';
    expect(c.previewTargets, isNotNull);
    c.onClose();
  });

  testWidgets('tapping prefilled onboarding height replaces it',
      (tester) async {
    final c = Get.put(OnboardingController(_Auth(), profiles));
    c.collectingProfile.value = true;
    await tester.pumpWidget(const GetMaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller == c.height);
    await tester.ensureVisible(field);
    await tester.tap(field);
    expect(c.height.selection,
        const TextSelection(baseOffset: 0, extentOffset: 3));
    await tester.enterText(field, '178');
    expect(c.height.text, '178');
  });

  test('progress goal uses Western digits', () {
    expect(AppStrings.progressDistantGoal(95).contains('95.0'), isTrue);
  });

  test('birth year parser rounds Arabic digits', () {
    expect(parseBirthYear('٢٠٠٠'), 2000);
  });
}
