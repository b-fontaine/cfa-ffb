import 'package:billard_cfa/entities/group/domain/choose_group.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_calendar.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unique_name.dart';

/// Une étape de la reconduction d'un groupe : le groupe d'origine **avec** les
/// élèves déjà libérés, et le groupe de la saison suivante **avec** ces mêmes
/// élèves admis. `CloseSeason` enregistre les deux dans une même unité de
/// travail ; la clôture reprenable enregistre la **destination d'abord**, puis
/// l'origine, dans des lots distincts (jamais un élève libéré sans être admis,
/// et la liste de groupes d'une fiche ne reçoit jamais un ajout et un retrait
/// dans le même lot). Rejouée, l'étape ne réadmet pas un élève déjà admis.
final class GroupStep {
  const GroupStep(this.released, this.destination, this.moved);

  final Group released;
  final Group destination;

  /// Élèves reconduits **par cette étape** (pas les précédentes).
  final int moved;
}

/// Ce qu'il faut écrire pour préparer la saison qui suit une clôture : la
/// saison suivante si elle n'existe pas, puis des étapes de groupe. Règle pure,
/// **sans** écriture : partagée par `CloseSeason` (tout en une unité de
/// travail) et par la clôture reprenable (lots), qui ne peuvent donc pas
/// diverger.
final class NextSeasonPlan {
  const NextSeasonPlan({required this.seasonToSave, required this.steps});

  /// La saison suivante à créer ; `null` si elle existe déjà.
  final Season? seasonToSave;

  /// Les étapes, dans l'ordre d'écriture ; chaque groupe d'origine en donne
  /// une ou plusieurs (un groupe de très nombreux élèves est reconduit par
  /// morceaux : l'écriture d'un groupe ne change que ce qui diffère).
  final List<GroupStep> steps;
}

/// Prépare la saison qui suit [closed] (fermée le [day]). [erased] : les élèves
/// qui ne sont pas reconduits. [newSeasonId] et [newGroupId] donnent les
/// identifiants des éléments **créés** : l'un aléatoire (une unité de travail),
/// l'autre dérivé de l'opération (la reprise retrouve les mêmes). [chunk] borne
/// les élèves reconduits par étape (`null` : tous d'un coup).
///
/// Rend `null` quand la saison suivante existe déjà **et est close** (rien à
/// reconduire).
NextSeasonPlan? planNextSeason({
  required Season closed,
  required DateTime day,
  required List<Season> seasons,
  required List<Group> groups,
  required Set<StudentId> erased,
  required SeasonId newSeasonId,
  required GroupId Function(Group origin) newGroupId,
  int? chunk,
}) {
  final candidate = nextSeasonAfter(
    closed,
    newSeasonId,
    takenLabels: {for (final s in seasons) s.label},
  );
  final existing = seasons
      .where((s) => s.id != closed.id && s.overlaps(candidate))
      .firstOrNull;
  if (existing != null && existing.isClosed) return null;
  final next = existing ?? candidate;
  // Les élèves reconduits rejoignent la saison suivante dès son premier jour,
  // même si la clôture a lieu après : ils ne sont pas « sans groupe » entre
  // son début et la clôture. L'ancienne appartenance finit la veille.
  final from = next.startDate.dateOnly;
  final lastDay = DateTime(from.year, from.month, from.day - 1);
  final releaseOn = lastDay.isBefore(day) ? lastDay : day;

  final steps = <GroupStep>[];
  for (final origin in groups.where((g) => g.seasonId == closed.id)) {
    final base =
        _homonym(groups, next.id, origin) ??
        _fresh(groups, next, origin, newGroupId(origin));
    final moving = [
      for (final membership in origin.memberships)
        if (membership.to == null && !erased.contains(membership.studentId))
          membership,
    ];
    final size = chunk ?? (moving.isEmpty ? 1 : moving.length);
    var released = origin;
    var destination = base;
    var inStep = 0;
    for (var i = 0; i < moving.length; i++) {
      final membership = moving[i];
      released = released.release(
        studentId: membership.studentId,
        to: releaseOn.isBefore(membership.from) ? membership.from : releaseOn,
      );
      // Déjà admis (une reprise après que la destination a été écrite, avant
      // que l'origine ne soit libérée) : on ne l'admet pas une seconde fois.
      final admitted = destination.memberships.any(
        (m) => m.studentId == membership.studentId && m.to == null,
      );
      if (!admitted) {
        destination = destination.admit(
          studentId: membership.studentId,
          studentAudience: destination.audience,
          from: from,
        );
      }
      inStep++;
      if (inStep == size || i == moving.length - 1) {
        steps.add(GroupStep(released, destination, inStep));
        inStep = 0;
      }
    }
    if (moving.isEmpty) steps.add(GroupStep(released, destination, 0));
  }
  return NextSeasonPlan(
    seasonToSave: existing == null ? candidate : null,
    steps: steps,
  );
}

Group? _homonym(List<Group> all, SeasonId seasonId, Group origin) {
  final wanted = normalizedGroupName(origin.name);
  for (final group in all) {
    if (group.seasonId == seasonId &&
        normalizedGroupName(group.name) == wanted &&
        group.audience == origin.audience) {
      return group;
    }
  }
  return null;
}

/// Un groupe neuf de la saison [next] portant le nom de [origin] ; si ce nom y
/// est pris par un groupe d'un autre public, il est suffixé (« (2) », « (3) »…
/// jusqu'à un nom libre : le nom reste unique dans la saison).
Group _fresh(List<Group> all, Season next, Group origin, GroupId id) {
  final taken = {
    for (final g in all)
      if (g.seasonId == next.id) normalizedGroupName(g.name),
  };
  return Group(
    id: id,
    seasonId: next.id,
    name: firstFreeName(
      origin.name,
      (c) => taken.contains(normalizedGroupName(c)),
    ),
    audience: origin.audience,
  );
}
