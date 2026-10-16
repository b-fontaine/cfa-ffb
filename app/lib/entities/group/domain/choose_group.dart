import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Forme comparable d'un nom de groupe : sans espaces de bord ni casse. Deux
/// groupes d'une même saison ne peuvent pas porter la même forme.
String normalizedGroupName(String name) => name.trim().toLowerCase();

/// Choisit le groupe qui accueille un élève de public [audience] dans la
/// saison [seasonId] (inscription, changement de public).
///
/// - Un groupe [requested] est accepté s'il est de la saison (sinon
///   `unknownGroup`) et du public (sinon `audienceMismatch`).
/// - Sans demande, un seul candidat est pris tel quel ; plusieurs candidats
///   lèvent `groupChoiceRequired` (l'interface demande alors le groupe).
/// - Aucun candidat : `null`, l'appelant crée le groupe.
Group? chooseGroup({
  required Iterable<Group> groups,
  required SeasonId seasonId,
  required Audience audience,
  GroupId? requested,
}) {
  final ofSeason = [
    for (final group in groups)
      if (group.seasonId == seasonId) group,
  ];
  if (requested != null) {
    final group = ofSeason.where((g) => g.id == requested).firstOrNull;
    if (group == null) {
      throw InvariantViolation(InvariantCode.unknownGroup, requested.value);
    }
    if (group.audience != audience) {
      throw const InvariantViolation(InvariantCode.audienceMismatch);
    }
    return group;
  }
  final candidates = [
    for (final group in ofSeason)
      if (group.audience == audience) group,
  ];
  if (candidates.length > 1) {
    throw const InvariantViolation(InvariantCode.groupChoiceRequired);
  }
  return candidates.firstOrNull;
}

/// Les groupes de public [audience] des saisons [seasons], proposés au
/// sélecteur d'un formulaire (nom et identifiant seulement), dans l'ordre des
/// groupes.
List<GroupChoice> groupChoices(
  Iterable<Group> groups, {
  required Audience audience,
  required Set<SeasonId> seasons,
}) => [
  for (final group in groups)
    if (group.audience == audience && seasons.contains(group.seasonId))
      GroupChoice(group.id, group.name),
];
