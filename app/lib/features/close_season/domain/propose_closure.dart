import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Les élèves qu'une clôture de [season] peut concerner : ceux qui ont une
/// appartenance dans un groupe de la saison, et ceux que plus rien ne place
/// dans une saison ouverte (aucune appartenance ouverte dans un groupe d'une
/// saison non close) : un élève jamais placé, ou gardé lors d'une clôture sans
/// saison suivante. Sans cela, leurs données ne seraient jamais proposées à
/// l'effacement (ADR 0019, minimisation des données des mineurs).
Set<StudentId> closureCandidates({
  required Season season,
  required Iterable<Student> students,
  required Iterable<Group> groups,
  required Iterable<Season> seasons,
}) {
  final closed = {
    for (final other in seasons)
      if (other.isClosed) other.id,
  };
  final enrolled = <StudentId>{};
  final placed = <StudentId>{};
  for (final group in groups) {
    for (final membership in group.memberships) {
      if (group.seasonId == season.id) enrolled.add(membership.studentId);
      if (membership.to == null && !closed.contains(group.seasonId)) {
        placed.add(membership.studentId);
      }
    }
  }
  return {
    for (final student in students)
      if (enrolled.contains(student.id) || !placed.contains(student.id))
        student.id,
  };
}

/// Règle pure : le choix proposé pour chaque élève concerné par la clôture
/// d'une saison (ADR 0019, voir [closureCandidates]). Dans cet ordre :
/// 1. aucune présence dans une séance de la saison : effacer (`inactive`) ;
/// 2. première inscription antérieure au début de la saison : effacer
///    (`retentionExpired`, la conservation est la saison en cours et la
///    suivante) ;
/// 3. sinon reconduire (`carriedOver`).
List<ClosureProposal> proposeClosure({
  required Season season,
  required Iterable<Season> seasons,
  required Iterable<Student> students,
  required Iterable<Group> groups,
  required Iterable<SessionRecord> sessions,
}) {
  final candidates = closureCandidates(
    season: season,
    students: students,
    groups: groups,
    seasons: seasons,
  );
  final active = <StudentId>{
    for (final session in sessions)
      if (session.seasonId == season.id) ...session.present,
  };
  final proposals =
      [
        for (final student in students)
          if (candidates.contains(student.id))
            () {
              final (choice, reason) = !active.contains(student.id)
                  ? (ClosureChoice.erase, ClosureReason.inactive)
                  : student.audienceHistory.first.effectiveFrom.isBefore(
                      season.startDate,
                    )
                  ? (ClosureChoice.erase, ClosureReason.retentionExpired)
                  : (ClosureChoice.keep, ClosureReason.carriedOver);
              return ClosureProposal(
                studentId: student.id,
                firstName: student.firstName,
                audience: student.currentAudience,
                choice: choice,
                reason: reason,
              );
            }(),
      ]..sort((a, b) {
        final byName = a.firstName.toLowerCase().compareTo(
          b.firstName.toLowerCase(),
        );
        return byName != 0
            ? byName
            : a.studentId.value.compareTo(b.studentId.value);
      });
  return proposals;
}
