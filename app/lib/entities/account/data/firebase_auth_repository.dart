import 'package:billard_cfa/entities/account/data/auth_sdk.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Authentification par Firebase Auth, derrière [AuthSdk].
///
/// Traduit les codes du SDK en `AuthFailureCode` génériques (anti-énumération,
/// ADR 0024, décision 31). L'application n'envoie aucun courriel : Firebase
/// Auth envoie seul ceux de vérification et de réinitialisation.
@LazySingleton(as: AuthRepository, env: [Environment.prod])
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._sdk);

  final AuthSdk _sdk;

  @override
  Stream<Account?> watchAccount() => _sdk.userChanges().map(_account);

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return _requireAccount(await _sdk.signInWithPassword(email, password));
    } on AuthSdkException catch (error) {
      throw _signInFailure(error);
    }
  }

  @override
  Future<Account> register({
    required String email,
    required String password,
  }) async {
    try {
      return _requireAccount(await _sdk.createUser(email, password));
    } on AuthSdkException catch (error) {
      throw _registerFailure(error);
    }
  }

  @override
  Future<void> sendEmailVerification() => _guard(_sdk.sendEmailVerification);

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _sdk.sendPasswordResetEmail(email);
    } on AuthSdkException catch (error) {
      // Une adresse inconnue ou refusée ne doit rien apprendre : seuls les
      // échecs qui ne dépendent pas de l'adresse sont rapportés.
      final failure = _transportFailure(error);
      if (failure != null) throw failure;
    }
  }

  @override
  Future<void> signOut() => _guard(_sdk.signOut);

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on AuthSdkException catch (error) {
      throw _transportFailure(error) ??
          AuthFailure(AuthFailureCode.unavailable, error.code);
    }
  }

  static Account? _account(AuthSdkUser? user) {
    if (user == null) return null;
    final email = user.email;
    // Un compte sans adresse (fournisseur non prévu) n'entre pas.
    if (email == null || email.isEmpty) return null;
    return Account(
      id: UserId(user.uid),
      email: email,
      emailVerified: user.emailVerified,
    );
  }

  static Account _requireAccount(AuthSdkUser user) =>
      _account(user) ?? (throw const AuthFailure(AuthFailureCode.unavailable));

  /// Échecs indépendants de l'adresse et du mot de passe.
  static AuthFailure? _transportFailure(AuthSdkException error) =>
      switch (error.code) {
        'network-request-failed' => AuthFailure(
          AuthFailureCode.network,
          error.code,
        ),
        'too-many-requests' => AuthFailure(
          AuthFailureCode.tooManyRequests,
          error.code,
        ),
        _ => null,
      };

  static AuthFailure _signInFailure(AuthSdkException error) =>
      _transportFailure(error) ??
      switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'user-disabled' ||
        'invalid-email' ||
        'invalid-login-credentials' => AuthFailure(
          AuthFailureCode.invalidCredentials,
          error.code,
        ),
        _ => AuthFailure(AuthFailureCode.unavailable, error.code),
      };

  static AuthFailure _registerFailure(AuthSdkException error) =>
      _transportFailure(error) ??
      switch (error.code) {
        'weak-password' => AuthFailure(
          AuthFailureCode.weakPassword,
          error.code,
        ),
        'invalid-email' => AuthFailure(
          AuthFailureCode.invalidEmail,
          error.code,
        ),
        'email-already-in-use' || 'operation-not-allowed' => AuthFailure(
          AuthFailureCode.registrationFailed,
          error.code,
        ),
        _ => AuthFailure(AuthFailureCode.unavailable, error.code),
      };
}
