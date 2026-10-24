import 'package:billard_cfa/entities/account/data/auth_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Passerelle vers `firebase_auth`. N'est appelée qu'une fois Firebase
/// initialisé (`AuthCubit` attend `SessionStartup.ready`) ;
/// `FirebaseAuth.instance` n'est lu qu'à l'appel, jamais à la construction.
///
/// Les fonctions du SDK sont injectables pour que les tests n'atteignent jamais
/// le plugin ni le réseau.
class FirebaseAuthSdk implements AuthSdk {
  FirebaseAuthSdk({FirebaseAuth Function()? auth})
    : _auth = auth ?? (() => FirebaseAuth.instance);

  final FirebaseAuth Function() _auth;

  @override
  Stream<AuthSdkUser?> userChanges() =>
      _auth().userChanges().map((user) => user == null ? null : _user(user));

  @override
  Future<AuthSdkUser> signInWithPassword(String email, String password) =>
      _guard(() async {
        final credential = await _auth().signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _user(credential.user!);
      });

  @override
  Future<AuthSdkUser> createUser(String email, String password) =>
      _guard(() async {
        final credential = await _auth().createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _user(credential.user!);
      });

  @override
  Future<void> sendEmailVerification() => _guard(() async {
    final user = _auth().currentUser;
    if (user == null) {
      throw const AuthSdkException('no-current-user');
    }
    await user.sendEmailVerification();
  });

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _guard(() => _auth().sendPasswordResetEmail(email: email));

  @override
  Future<void> signOut() => _guard(() => _auth().signOut());

  @override
  Future<void> reauthenticate(String password) => _guard(() async {
    final user = _currentUser();
    final email = user.email;
    if (email == null) throw const AuthSdkException('no-current-user');
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  });

  @override
  Future<void> deleteUser() => _guard(() => _currentUser().delete());

  User _currentUser() =>
      _auth().currentUser ?? (throw const AuthSdkException('no-current-user'));

  static AuthSdkUser _user(User user) => AuthSdkUser(
    uid: user.uid,
    email: user.email,
    emailVerified: user.emailVerified,
  );

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseAuthException catch (error) {
      throw AuthSdkException(error.code, error.message);
    }
  }
}
