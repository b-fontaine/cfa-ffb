import 'package:billard_cfa/entities/group/domain/current_groups.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les groupes dont on peut imprimer les prénoms sur les fiches
/// résultats, ceux des saisons en cours (règle de la vue du club). N'expose que
/// l'identifiant et le nom du groupe, aucun élève.
@injectable
class ListExportGroups {
  ListExportGroups(this._groups, this._seasons, this._clock);

  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final Clock _clock;

  Future<Result<List<GroupChoice>>> call() => runGuarded(() async {
    final today = _clock.today();
    final seasons = await _seasons.all();
    final groups = currentGroups(
      await _groups.all(),
      currentSeasons: {
        for (final season in seasons)
          if (season.isOpenOn(today)) season.id,
      },
      closedSeasons: {
        for (final season in seasons)
          if (season.isClosed) season.id,
      },
    );
    return [for (final group in groups) GroupChoice(group.id, group.name)];
  });
}
