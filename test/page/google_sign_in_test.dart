import 'package:diet_app2/data/repositories/profile_repository.dart';
import 'package:diet_app2/domain/profile/user_profile.dart';
import 'package:diet_app2/page/onboarding/onboarding_controller.dart';
import 'package:diet_app2/service/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _User implements User {
  @override
  String get uid => 'g';
  @override
  String? get email => 'g@gmail.com';
  @override
  String? get displayName => 'Google User';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements AuthService {
  _Auth(this.result);
  final Object result; // a User, or an AuthFailure to throw
  @override
  User? get currentUser => null;
  @override
  Future<User> signInWithGoogle() async {
    final r = result;
    if (r is AuthFailure) throw r;
    return r as User;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements ProfileRepository {
  @override
  Future<UserProfile?> get(String uid) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(Get.reset);

  test('first Google sign-in continues to the profile step with name/email',
      () async {
    final c = OnboardingController(_Auth(_User()), _Profiles())..onInit();
    await c.signInWithGoogle();
    expect(c.collectingProfile.value, isTrue);
    expect(c.name.text, 'Google User');
    expect(c.email.text, 'g@gmail.com');
    expect(c.error.value, isNull);
    expect(c.busy.value, isFalse);
    c.onClose();
  });

  test('closing the Google page is not shown as an error', () async {
    final c = OnboardingController(
        _Auth(const AuthFailure('canceled', 'x')), _Profiles())
      ..onInit();
    await c.signInWithGoogle();
    expect(c.error.value, isNull);
    expect(c.collectingProfile.value, isFalse);
    c.onClose();
  });

  test('provider disabled shows a clear message', () async {
    final failure =
        mapAuthFailure(FirebaseAuthException(code: 'operation-not-allowed'));
    final c = OnboardingController(_Auth(failure), _Profiles())..onInit();
    await c.signInWithGoogle();
    expect(c.error.value, failure.messageAr);
    c.onClose();
  });

  test('cancel codes from the web flow all map to canceled', () {
    for (final code in ['web-context-canceled', 'canceled', 'cancelled']) {
      expect(mapAuthFailure(FirebaseAuthException(code: code)).code,
          'canceled');
    }
  });
}
