import 'package:billard_cfa/entities/membership/domain/own_link.dart';
import 'package:billard_cfa/entities/membership/domain/own_link_source.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Ce que le serveur dit, maintenant, de l'accès d'un parent ou d'un élève.
sealed class FamilyAccess {
  const FamilyAccess();
}

/// L'accès demeure pour [studentIds] : les fiches de la session que le lien du
/// compte liste encore (parfois moins qu'à la connexion : retrait partiel).
final class AccessGranted extends FamilyAccess {
  const AccessGranted(this.studentIds);

  final Set<StudentId> studentIds;
}

/// Plus aucune fiche de la session n'est liée au compte : accès retiré.
final class AccessRevoked extends FamilyAccess {
  const AccessRevoked();
}

/// Cas d'usage : l'accès du compte à ses fiches tient-il encore (FB6) ?
///
/// Relit le **propre** lien du compte et le confronte aux fiches de la
/// session (figées à la connexion). Un `member` absent, un lien vide ou sans
/// aucune des fiches de la session : accès retiré. Un lien qui ne perd qu'une
/// fiche : l'accès demeure pour les autres. Un lien illisible faute de réseau
/// ne change rien (on ne retire pas un accès sur une simple coupure).
@injectable
class CheckFamilyAccess {
  CheckFamilyAccess(this._link, this._scope);

  final OwnLinkSource _link;
  final ActiveClubScope _scope;

  Future<FamilyAccess> call() async {
    final session = _scope.studentIds.toSet();
    final OwnLink? link;
    try {
      link = await _link.read();
    } on ServiceFailure {
      return AccessGranted(session);
    }
    final linked = link?.studentIds.intersection(session) ?? const {};
    return linked.isEmpty ? const AccessRevoked() : AccessGranted(linked);
  }
}
