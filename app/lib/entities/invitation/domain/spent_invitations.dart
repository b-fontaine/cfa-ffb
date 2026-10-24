import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';

/// Port : les invitations **utilisées ou échues** du club actif, que la
/// clôture de saison supprime (ADR 0025, décision 6 ; FB8 partie B, décision
/// D3 du 2026-10-24). Une invitation révoquée est déjà supprimée ; une
/// invitation encore valable reste.
///
/// La liste est celle que les règles ouvrent au compte courant : **bornée au
/// club** (la requête porte `clubId ==`) ; l'administrateur voit tous les
/// rôles, le directeur **seulement les rôles qu'il invite** (une requête par
/// rôle, `role ==`) : il ne lit jamais le code d'une invitation de directeur,
/// qui lui permettrait de fabriquer un second directeur. L'invitation de
/// directeur échue reste donc jusqu'à la clôture d'un administrateur.
abstract interface class SpentInvitations {
  /// Les codes des invitations du club actif utilisées, ou échues à l'heure
  /// de l'appareil, que le compte courant peut lister (aucune écriture).
  Future<List<InvitationCode>> codes();

  /// Le lot qui supprime les invitations [codes] (une écriture chacune),
  /// appliqué par le magasin d'opérations avec le marqueur. Idempotent pour
  /// l'administrateur ; pour le directeur, les règles refusent la suppression
  /// d'une invitation qui n'existe plus (le lot échoue, la reprise recalcule
  /// ce qui reste).
  OperationLot remove(List<InvitationCode> codes);
}
