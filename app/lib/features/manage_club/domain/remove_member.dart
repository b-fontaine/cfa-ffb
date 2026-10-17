import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/entities/membership/domain/member_removal.dart';
import 'package:billard_cfa/entities/membership/domain/member_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : retirer l'accès d'un membre au club (son compte reste).
///
/// Le directeur retire un enseignant, un élève ou un parent, jamais un
/// directeur ni lui-même ; seul l'administrateur retire un directeur (règles
/// Firestore, ADR 0024 décision 14).
@injectable
class RemoveMember {
  RemoveMember(this._members, this._scope, this._user);

  final MemberRepository _members;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  Future<Result<void>> call(Member member) => runGuarded(() async {
    final session = requireClubSession(
      _scope,
      _user,
      capability: Capability.manageClub,
    );
    if (!canRemoveMember(
      viewerRole: session.role,
      viewerId: session.user,
      member: member,
    )) {
      throw const InvariantViolation(InvariantCode.actionNotAllowed);
    }
    await _members.remove(session.club, member.uid);
  });
}
