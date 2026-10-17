import 'package:billard_cfa/entities/group/domain/current_groups.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/club_session.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les groupes courants que le directeur (ou l'administrateur)
/// peut confier à un enseignant invité, par nom. Un enseignant n'invite pas
/// d'enseignant : il n'a pas cette liste.
@injectable
class ListInvitableGroups {
  ListInvitableGroups(
    this._groups,
    this._seasons,
    this._clock,
    this._scope,
    this._user,
  );

  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final Clock _clock;
  final ActiveClubScope _scope;
  final CurrentUser _user;

  Future<Result<List<Group>>> call() => runGuarded(() async {
    requireClubSession(_scope, _user, capability: Capability.inviteTeachers);
    final today = _clock.today();
    final seasons = await _seasons.all();
    final groups = [
      ...currentGroups(
        await _groups.all(),
        currentSeasons: {
          for (final season in seasons)
            if (season.isOpenOn(today)) season.id,
        },
        closedSeasons: {
          for (final season in seasons)
            if (season.isClosed) season.id,
        },
      ),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return groups;
  });
}
