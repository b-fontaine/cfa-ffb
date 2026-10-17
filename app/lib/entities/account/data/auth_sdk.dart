/// Utilisateur tel que le SDK le décrit (aucun type du SDK ne sort d'ici).
class AuthSdkUser {
  const AuthSdkUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
  });

  final String uid;
  final String? email;
  final bool emailVerified;
}

/// Erreur du SDK, réduite à son code (`invalid-credential`,
/// `network-request-failed`…).
class AuthSdkException implements Exception {
  const AuthSdkException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() =>
      'AuthSdkException($code${message == null ? '' : ': $message'})';
}

/// Frontière du SDK d'authentification : les opérations brutes, rien de plus.
/// L'implémentation réelle (`app/platform/firebase_auth_sdk.dart`) n'est
/// appelée qu'une fois Firebase initialisé ; les tests en fournissent une
/// fausse et n'atteignent jamais le SDK ni le réseau.
abstract interface class AuthSdk {
  /// Utilisateur courant : session persistée d'abord, puis chaque changement.
  Stream<AuthSdkUser?> userChanges();

  Future<AuthSdkUser> signInWithPassword(String email, String password);

  Future<AuthSdkUser> createUser(String email, String password);

  Future<void> sendEmailVerification();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
