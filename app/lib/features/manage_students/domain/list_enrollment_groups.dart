import 'package:billard_cfa/entities/group/domain/choose_group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les groupes qui peuvent accueillir un nouvel élève de public
/// `audience` aujourd'hui (saisons ouvertes), pour le sélecteur du formulaire
/// d'inscription quand il y en a plusieurs (ADR 0019).
@injectable
class ListEnrollmentGroups {
  ListEnrollmentGroups(this._groups, this._seasons);

  final GroupRepository _groups;
  final SeasonRepository _seasons;

  Future<Result<List<GroupChoice>>> call({
    required Audience audience,
    required DateTime today,
  }) => runGuarded(() async {
    final open = {
      for (final season in await _seasons.all())
        if (season.isOpenOn(today)) season.id,
    };
    return groupChoices(await _groups.all(), audience: audience, seasons: open);
  });
}
