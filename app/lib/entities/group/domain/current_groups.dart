import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Les groupes des saisons [currentSeasons] (celles qui contiennent le jour
/// courant) ; tous les groupes quand aucune saison n'est en cours. Règle
/// unique de la vue du club et de la planification.
List<Group> currentGroups(
  Iterable<Group> groups, {
  required Set<SeasonId> currentSeasons,
}) => List.unmodifiable(
  currentSeasons.isEmpty
      ? groups
      : groups.where((group) => currentSeasons.contains(group.seasonId)),
);
