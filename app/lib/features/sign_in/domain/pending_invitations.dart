import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Le code d'invitation qu'un compte tout juste créé doit encore faire valoir.
///
/// **Point d'extension du lot FB3** : l'inscription crée le compte, garde le
/// code sur l'appareil sous l'identifiant du compte, puis FB3 le lit après la
/// première connexion vérifiée, le consomme (lot d'écritures contrôlé par les
/// règles : mise à jour de l'invitation et création du `member`) et l'efface.
/// Rien n'est consommé ni créé côté serveur dans le lot FB2.
abstract interface class PendingInvitations {
  Future<void> hold(UserId user, InvitationCode code);

  Future<InvitationCode?> read(UserId user);

  Future<void> clear(UserId user);
}
