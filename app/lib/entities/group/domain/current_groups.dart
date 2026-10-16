import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Les groupes des saisons [currentSeasons] (celles qui sont ouvertes le jour
/// courant) ; tous les groupes quand aucune saison n'est en cours. Règle
/// unique de la vue du club et de la planification.
///
/// Les groupes d'une saison de [closedSeasons] ne sont jamais rendus, même au
/// repli « aucune saison en cours » : une saison close n'accueille plus rien.
List<Group> currentGroups(
  Iterable<Group> groups, {
  required Set<SeasonId> currentSeasons,
  Set<SeasonId> closedSeasons = const {},
}) {
  final open = groups.where((group) => !closedSeasons.contains(group.seasonId));
  return List.unmodifiable(
    currentSeasons.isEmpty
        ? open
        : open.where((group) => currentSeasons.contains(group.seasonId)),
  );
}
