import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/entities/membership/domain/member_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les membres du club actif (équipe et familles), pour le
/// directeur et l'administrateur. L'enseignant, l'élève et le parent ne lisent
/// que leur propre member (règles Firestore) : ils sont refusés ici aussi.
@injectable
class ListMembers {
  ListMembers(this._members, this._scope, this._user);

  final MemberRepository _members;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  Future<Result<List<Member>>> call() => runGuarded(() async {
    final session = requireClubSession(
      _scope,
      _user,
      capability: Capability.manageClub,
    );
    final members = await _members.membersOf(session.club);
    return members;
  });
}
