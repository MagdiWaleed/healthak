import 'package:diet_app2/service/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Firebase auth errors to actionable Arabic messages', () {
    final failure =
        mapAuthFailure(FirebaseAuthException(code: 'invalid-email'));
    expect(failure.code, 'invalid-email');
    expect(failure.messageAr, isNotEmpty);
  });
}
