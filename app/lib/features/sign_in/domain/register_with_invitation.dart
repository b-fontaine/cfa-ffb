import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:billard_cfa/features/sign_in/domain/pending_invitations.dart';
import 'package:injectable/injectable.dart';

/// Résultat d'une inscription : le compte existe ; [verificationSent] dit si
/// le courriel de vérification est parti (sinon « Renvoyer » reste possible
/// depuis l'écran de connexion).
class Registration {
  const Registration({required this.verificationSent});

  final bool verificationSent;
}

/// Inscription fermée : un code d'invitation est obligatoire (ADR 0024,
/// décision 24).
///
/// Ce lot ne crée **que le compte d'authentification** : contrôle de la forme
/// du code, mot de passe d'au moins [minPasswordLength] caractères, création du
/// compte, courriel de vérification, puis le code est gardé sur l'appareil
/// ([PendingInvitations], point d'extension de FB3) et la session est fermée
/// (l'adresse n'est pas vérifiée). L'existence du code, sa consommation et la
/// création du `member` relèvent de FB3 : rien n'est simulé ici.
@injectable
class RegisterWithInvitation {
  RegisterWithInvitation(this._auth, this._pending);

  final AuthRepository _auth;
  final PendingInvitations _pending;

  Future<Registration> call({
    required String code,
    required String email,
    required String password,
  }) async {
    final invitation = InvitationCode.parse(code);
    if (!isPlausibleEmail(email)) {
      throw const AuthFailure(AuthFailureCode.invalidEmail);
    }
    if (password.length < minPasswordLength) {
      throw const AuthFailure(AuthFailureCode.weakPassword);
    }
    final account = await _auth.register(
      email: email.trim(),
      password: password,
    );
    var sent = true;
    try {
      await _pending.hold(account.id, invitation);
      await _auth.sendEmailVerification();
    } on AuthFailure {
      sent = false;
    } finally {
      await _auth.signOut();
    }
    return Registration(verificationSent: sent);
  }
}
