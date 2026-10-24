import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';

/// Port d'accès aux invitations (implémenté dans la couche data).
///
/// Les droits sont ceux de `firestore.rules` : lecture par le code (la liste
/// bornée au club ne sert qu'à la révocation de ses propres invitations,
/// [unusedIssuedBy]),
/// création selon le rôle, révocation par le créateur, le
/// directeur ou l'administrateur, consommation unique dans le même lot que la
/// création du `member`. Les pannes du service lèvent `ServiceFailure`.
abstract interface class InvitationRepository {
  /// Crée l'invitation (la date de création est celle du serveur).
  Future<void> create(Invitation invitation);

  /// L'invitation de ce code ; `null` si elle n'existe pas (jamais créée, ou
  /// révoquée).
  Future<Invitation?> find(InvitationCode code);

  /// Révoque l'invitation (la supprime) ; sans effet si elle n'existe plus.
  Future<void> revoke(InvitationCode code);

  /// Les codes des invitations **non utilisées** que [user] a créées dans
  /// [club], depuis n'importe quel appareil, **lues au serveur** (jamais le
  /// cache : la suppression d'un compte ne doit pas croire qu'il n'en reste
  /// aucune). Les règles n'ouvrent cette liste qu'à un membre du club, pour
  /// ses propres invitations (FB8 partie B). Lève `ServiceFailure`.
  Future<List<InvitationCode>> unusedIssuedBy(UserId user, ClubId club);

  /// Accepte l'invitation pour [user] : vérifie qu'elle existe, n'a pas servi
  /// et n'a pas expiré, puis, dans **un seul lot**, crée le `member` (rôle,
  /// club, groupes et fiches de l'invitation) et consomme l'invitation. Lève
  /// `InvitationFailure` si le code ne convient pas.
  Future<void> accept({
    required InvitationCode code,
    required UserId user,
    required String displayName,
  });
}
