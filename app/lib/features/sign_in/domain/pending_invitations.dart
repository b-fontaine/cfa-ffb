import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';

/// Le code d'invitation qu'un compte tout juste créé doit encore faire valoir.
///
/// L'inscription (FB2) crée le compte et garde le code sur l'appareil sous
/// l'identifiant du compte ; après la première connexion vérifiée, `AuthCubit`
/// le lit (FB3), l'écran « Rejoindre un club » le propose, et
/// `AcceptInvitation` le consomme (lot d'écritures contrôlé par les règles :
/// mise à jour de l'invitation et création du `member`) puis l'efface.
abstract interface class PendingInvitations {
  Future<void> hold(UserId user, InvitationCode code);

  Future<InvitationCode?> read(UserId user);

  Future<void> clear(UserId user);
}
