import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:injectable/injectable.dart';

/// Connexion par adresse et mot de passe.
///
/// L'adresse doit être **vérifiée** (ADR 0024, décision 24) : sinon le compte
/// est aussitôt déconnecté et l'échec est `emailNotVerified`. Cet échec n'est
/// rendu qu'après des identifiants justes, il ne révèle donc rien à qui ne
/// connaît pas le mot de passe.
@injectable
class SignIn {
  SignIn(this._auth);

  final AuthRepository _auth;

  Future<Account> call({
    required String email,
    required String password,
  }) async {
    if (!isPlausibleEmail(email)) {
      throw const AuthFailure(AuthFailureCode.invalidEmail);
    }
    if (password.isEmpty) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
    final account = await _auth.signIn(email: email.trim(), password: password);
    if (!account.emailVerified) {
      await _auth.signOut();
      throw const AuthFailure(AuthFailureCode.emailNotVerified);
    }
    return account;
  }
}
