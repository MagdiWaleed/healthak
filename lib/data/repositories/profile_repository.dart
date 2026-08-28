import '../../domain/profile/user_profile.dart';
import '../firestore_refs.dart';

abstract interface class ProfileCache {
  Future<void> saveProfile(UserProfile profile);
  Future<void> clearProfile();
}

class ProfileRepository {
  final FirestoreRefs _refs;
  final ProfileCache? _cache;

  ProfileRepository({FirestoreRefs? refs, ProfileCache? cache})
      : _refs = refs ?? FirestoreRefs(),
        _cache = cache;

  Future<UserProfile?> get(String uid) async =>
      (await _refs.profiles.doc(uid).get()).data();

  Stream<UserProfile?> watch(String uid) =>
      _refs.profiles.doc(uid).snapshots().map((snapshot) => snapshot.data());

  Future<void> save(UserProfile profile) async {
    await _refs.profiles.doc(profile.uid).set(profile);
    await _cache?.saveProfile(profile);
  }

  Future<void> clearCache() async => _cache?.clearProfile();

  /// Removes the Firestore profile document. Does not touch the Firebase
  /// Auth account itself -- callers delete the auth user separately and are
  /// expected to call this alongside it, so neither is left orphaned.
  Future<void> delete(String uid) async {
    await _refs.profiles.doc(uid).delete();
    await _cache?.clearProfile();
  }
}
