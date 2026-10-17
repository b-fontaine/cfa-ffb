import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:injectable/injectable.dart';

/// Renvoie le courriel de vérification à qui n'a pas pu entrer.
///
/// Le renvoi exige les identifiants (le fournisseur n'envoie qu'au compte
/// connecté) : un mauvais mot de passe échoue comme à la connexion. Le compte
/// est toujours déconnecté ensuite ; renvoie `false` si l'adresse était déjà
/// vérifiée (rien n'est envoyé).
@injectable
class ResendVerification {
  ResendVerification(this._auth);

  final AuthRepository _auth;

  Future<bool> call({required String email, required String password}) async {
    if (!isPlausibleEmail(email)) {
      throw const AuthFailure(AuthFailureCode.invalidEmail);
    }
    final account = await _auth.signIn(email: email.trim(), password: password);
    try {
      if (account.emailVerified) return false;
      await _auth.sendEmailVerification();
      return true;
    } finally {
      await _auth.signOut();
    }
  }
}
