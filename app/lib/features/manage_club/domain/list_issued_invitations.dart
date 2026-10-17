import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les invitations émises depuis cet appareil dans le club
/// actif, avec leur état (en attente, utilisée, expirée, inconnu hors ligne).
@injectable
class ListIssuedInvitations {
  ListIssuedInvitations(this._issued, this._scope, this._user);

  final IssuedInvitations _issued;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  Future<Result<List<IssuedInvitationStatus>>> call() => runGuarded(() async {
    final session = requireClubSession(
      _scope,
      _user,
      capability: Capability.openClub,
    );
    final statuses = await _issued.statuses(session.user, session.club);
    return statuses;
  });
}
