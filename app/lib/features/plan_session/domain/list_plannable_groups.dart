import 'package:billard_cfa/entities/group/domain/current_groups.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les groupes pour lesquels une séance peut être planifiée,
/// ceux de la saison en cours (tous si aucune saison ne contient `today`),
/// même sans membre : la planification précède parfois les inscriptions.
@injectable
class ListPlannableGroups {
  ListPlannableGroups(this._groups, this._seasons);

  final GroupRepository _groups;
  final SeasonRepository _seasons;

  Future<List<Group>> call({required DateTime today}) async => currentGroups(
    await _groups.all(),
    currentSeasons: {
      for (final season in await _seasons.all())
        if (season.contains(today)) season.id,
    },
  );
}
