import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:injectable/injectable.dart';

/// « Mot de passe oublié » : demande le courriel de réinitialisation.
///
/// Anti-énumération : l'appel aboutit de la même façon que l'adresse soit
/// connue ou non ; l'écran dit seulement « si un compte existe… ».
@injectable
class RequestPasswordReset {
  RequestPasswordReset(this._auth);

  final AuthRepository _auth;

  Future<void> call({required String email}) async {
    if (!isPlausibleEmail(email)) {
      throw const AuthFailure(AuthFailureCode.invalidEmail);
    }
    await _auth.sendPasswordReset(email.trim());
  }
}
