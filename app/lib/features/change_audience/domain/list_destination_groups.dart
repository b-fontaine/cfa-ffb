import 'package:billard_cfa/entities/group/domain/choose_group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les groupes de public `audience` qui peuvent accueillir
/// l'élève au changement de public (ADR 0019) : ceux de la saison de son
/// groupe actuel, ou des saisons ouvertes aujourd'hui s'il n'en a pas.
@injectable
class ListDestinationGroups {
  ListDestinationGroups(this._groups, this._seasons);

  final GroupRepository _groups;
  final SeasonRepository _seasons;

  Future<Result<List<GroupChoice>>> call({
    required StudentId studentId,
    required Audience audience,
    required DateTime today,
  }) => runGuarded(() async {
    final groups = await _groups.all();
    final seasons = <SeasonId>{
      for (final group in groups)
        if (group.memberships.any(
          (m) => m.studentId == studentId && m.to == null,
        ))
          group.seasonId,
    };
    if (seasons.isEmpty) {
      seasons.addAll({
        for (final season in await _seasons.all())
          if (season.isOpenOn(today)) season.id,
      });
    }
    return groupChoices(groups, audience: audience, seasons: seasons);
  });
}
