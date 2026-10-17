import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux membres d'un club (implémenté dans la couche data).
///
/// Les droits sont ceux de `firestore.rules` : le directeur et
/// l'administrateur lisent et retirent ; l'enseignant, l'élève et le parent ne
/// lisent que leur propre member. Les échecs du service lèvent
/// `ServiceFailure`.
abstract interface class MemberRepository {
  /// Les membres du club, triés par nom affiché.
  Future<List<Member>> membersOf(ClubId club);

  /// Retire l'accès de [user] au club (supprime son member ; son compte reste).
  Future<void> remove(ClubId club, UserId user);
}
