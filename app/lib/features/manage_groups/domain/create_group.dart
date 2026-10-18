import 'package:billard_cfa/entities/group/domain/choose_group.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : créer un groupe (nom + public) dans une saison ouverte.
///
/// Le nom est unique dans la saison, casse et espaces de bord ignorés
/// (`groupNameTaken`) : la règle est ici, pas dans une contrainte SQL.
@injectable
class CreateGroup {
  CreateGroup(this._groups, this._seasons, this._ids);

  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final IdGenerator _ids;

  Future<Result<Group>> call({
    required SeasonId seasonId,
    required String name,
    required Audience audience,
  }) => runGuarded(() async {
    final season = await _seasons.byId(seasonId);
    if (season == null) throw NotFound('season', seasonId.value);
    if (season.isClosed) {
      throw const InvariantViolation(InvariantCode.seasonClosed);
    }
    requireGroupNameFits(name);
    final group = Group(
      id: GroupId(_ids.next()),
      seasonId: seasonId,
      name: name.trim(),
      audience: audience,
    );
    final wanted = normalizedGroupName(group.name);
    final taken = (await _groups.all()).any(
      (other) =>
          other.seasonId == seasonId &&
          normalizedGroupName(other.name) == wanted,
    );
    if (taken) throw const InvariantViolation(InvariantCode.groupNameTaken);
    await _groups.save(group);
    return group;
  });
}
