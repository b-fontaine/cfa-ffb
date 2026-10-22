import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/close_season/domain/propose_closure.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Ce que la clôture a vérifié avant d'écrire quoi que ce soit.
final class CheckedClosure {
  const CheckedClosure({
    required this.season,
    required this.day,
    required this.groups,
    required this.seasonGroups,
    required this.kept,
  });

  final Season season;

  /// Le jour de clôture, sans heure.
  final DateTime day;
  final List<Group> groups;
  final List<Group> seasonGroups;

  /// Élèves reconduits : ceux qui ont encore une appartenance ouverte dans la
  /// saison et ne sont pas effacés.
  final Set<StudentId> kept;
}

/// Les conditions d'une clôture, partagées par `CloseSeason` (une unité de
/// travail) et la clôture reprenable : la saison existe et est ouverte, le jour
/// suit son début, chaque élève à effacer est concerné par la clôture.
Future<CheckedClosure> checkClosure({
  required SeasonRepository seasons,
  required GroupRepository groups,
  required StudentRepository students,
  required SeasonId seasonId,
  required DateTime closedOn,
  required Set<StudentId> erase,
}) async {
  final season = await seasons.byId(seasonId);
  if (season == null) throw NotFound('season', seasonId.value);
  if (season.isClosed) {
    throw const InvariantViolation(InvariantCode.seasonAlreadyClosed);
  }
  final day = closedOn.dateOnly;
  if (!day.isAfter(season.startDate)) {
    throw const InvariantViolation(InvariantCode.invalidPeriod);
  }
  final all = await groups.all();
  final seasonGroups = [
    for (final group in all)
      if (group.seasonId == seasonId) group,
  ];
  final candidates = closureCandidates(
    season: season,
    students: await students.all(),
    groups: all,
    seasons: await seasons.all(),
  );
  for (final id in erase) {
    if (!candidates.contains(id)) throw NotFound('student', id.value);
  }
  // Reconduits : ceux qui ont encore une appartenance ouverte dans la saison
  // et ne sont pas effacés (ceux qui l'avaient déjà quittée ne le sont pas).
  final kept = <StudentId>{
    for (final group in seasonGroups)
      for (final membership in group.memberships)
        if (membership.to == null && !erase.contains(membership.studentId))
          membership.studentId,
  };
  return CheckedClosure(
    season: season,
    day: day,
    groups: all,
    seasonGroups: seasonGroups,
    kept: kept,
  );
}
