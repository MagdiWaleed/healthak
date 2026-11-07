import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class AuthFailure implements Exception {
  final String code;
  final String messageAr;

  const AuthFailure(this.code, this.messageAr);

  @override
  String toString() => messageAr;
}

class AuthService extends GetxService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(displayName.trim());
      return user;
    } on FirebaseAuthException catch (error) {
      throw mapAuthFailure(error);
    }
  }

  Future<User> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (error) {
      throw mapAuthFailure(error);
    }
  }

  /// Google ("Gmail") sign-in through Firebase Auth's own provider flow,
  /// which opens Google's sign-in page in a browser tab. Deliberately not the
  /// `google_sign_in` package (removed earlier at the user's request).
  /// Needs the Google provider enabled in the Firebase console and the app's
  /// SHA-1 registered. Signing in with a Google account whose email already
  /// has an email/password account signs into that same account.
  Future<User> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      final credential = await _auth.signInWithProvider(provider);
      return credential.user!;
    } on FirebaseAuthException catch (error) {
      throw mapAuthFailure(error);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw mapAuthFailure(error);
    }
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('no-user', 'لا يوجد مستخدم مسجل');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (error) {
      throw mapAuthFailure(error);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (error) {
      throw mapAuthFailure(error);
    }
  }
}

AuthFailure mapAuthFailure(FirebaseAuthException error) => switch (error.code) {
      'invalid-email' =>
        const AuthFailure('invalid-email', 'البريد الإلكتروني غير صحيح'),
      'weak-password' =>
        const AuthFailure('weak-password', 'كلمة المرور ضعيفة'),
      'email-already-in-use' => const AuthFailure(
          'email-already-in-use', 'البريد الإلكتروني مستخدم بالفعل'),
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        const AuthFailure(
            'invalid-credential', 'البريد الإلكتروني أو كلمة المرور غير صحيحة'),
      'requires-recent-login' => const AuthFailure(
          'requires-recent-login', 'سجل الدخول مرة أخرى لإكمال العملية'),
      'network-request-failed' =>
        const AuthFailure('network-request-failed', 'تعذر الاتصال بالإنترنت'),
      'operation-not-allowed' => const AuthFailure(
          'operation-not-allowed', 'تسجيل الدخول بحساب Google غير مفعّل بعد'),
      'web-context-canceled' ||
      'web-context-cancelled' ||
      'canceled' ||
      'cancelled' ||
      'web-context-already-presented' =>
        const AuthFailure('canceled', 'تم إلغاء تسجيل الدخول'),
      'account-exists-with-different-credential' => const AuthFailure(
          'account-exists-with-different-credential',
          'هذا البريد مسجل بطريقة أخرى. سجّل الدخول بالبريد وكلمة المرور'),
      _ => AuthFailure(error.code, 'حدث خطأ. حاول مرة أخرى'),
    };
