import 'package:billard_cfa/entities/club/domain/club_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : renommer le club actif (directeur ou administrateur). Le nom
/// ne peut être vide ni dépasser `maxClubNameLength` caractères.
@injectable
class RenameClub {
  RenameClub(this._clubs, this._scope, this._user);

  final ClubRepository _clubs;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  Future<Result<void>> call(String name) => runGuarded(() async {
    final session = requireClubSession(
      _scope,
      _user,
      capability: Capability.manageClub,
    );
    await _clubs.rename(session.club, name);
  });
}
