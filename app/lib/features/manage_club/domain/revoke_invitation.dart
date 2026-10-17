import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : révoquer une invitation du club actif (la supprimer sur le
/// serveur : son code ne sert plus). Le créateur, le directeur et
/// l'administrateur le peuvent ; les règles refusent les autres.
@injectable
class RevokeInvitation {
  RevokeInvitation(this._issued, this._scope, this._user);

  final IssuedInvitations _issued;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  Future<Result<void>> call(InvitationCode code) => runGuarded(() async {
    final session = requireClubSession(
      _scope,
      _user,
      capability: Capability.openClub,
    );
    await _issued.revoke(session.user, session.club, code);
  });
}
