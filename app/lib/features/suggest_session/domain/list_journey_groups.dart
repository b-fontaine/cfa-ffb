import 'package:billard_cfa/entities/group/domain/current_groups.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les groupes proposés au sélecteur du catalogue, ceux des
/// saisons en cours (tous si aucune saison ne contient aujourd'hui), même sans
/// élève : la règle est celle du planificateur et de la vue du club.
@injectable
class ListJourneyGroups {
  ListJourneyGroups(this._groups, this._seasons, this._clock);

  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final Clock _clock;

  Future<Result<List<GroupChoice>>> call() => runGuarded(() async {
    final today = _clock.today();
    final groups = currentGroups(
      await _groups.all(),
      currentSeasons: {
        for (final season in await _seasons.all())
          if (season.contains(today)) season.id,
      },
    );
    return [for (final group in groups) GroupChoice(group.id, group.name)];
  });
}
