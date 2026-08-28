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
      _ => AuthFailure(error.code, 'حدث خطأ. حاول مرة أخرى'),
    };
