import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Chaque référence pointe vers un élément de la même sauvegarde.
class BackupReferences {
  const BackupReferences();

  void check(BackupSnapshot snapshot) {
    final seasons = {for (final s in snapshot.seasons) s.id};
    final students = {for (final s in snapshot.students) s.id};
    final groups = {for (final g in snapshot.groups) g.id};
    final sessions = {for (final s in snapshot.sessionRecords) s.id};

    for (final group in snapshot.groups) {
      _require(seasons.contains(group.seasonId));
      for (final membership in group.memberships) {
        _require(students.contains(membership.studentId));
      }
    }
    for (final session in snapshot.sessionRecords) {
      _require(groups.contains(session.groupId));
      _require(seasons.contains(session.seasonId));
      _requireAll(session.present, students);
    }
    for (final attempt in snapshot.attempts) {
      _require(students.contains(attempt.studentId));
      _require(sessions.contains(attempt.sessionId));
    }
    for (final assessment in snapshot.assessments) {
      _require(students.contains(assessment.studentId));
    }
    for (final acquisition in snapshot.blockAcquisitions) {
      _require(students.contains(acquisition.studentId));
    }
    for (final acknowledgement
        in snapshot.alertAcknowledgements ?? const <AlertAcknowledgement>[]) {
      _require(students.contains(acknowledgement.studentId));
    }
    // Une archive décrit une saison du fichier, et une saison close.
    final closed = {
      for (final s in snapshot.seasons)
        if (s.isClosed) s.id,
    };
    for (final archive in snapshot.seasonArchives) {
      _require(closed.contains(archive.seasonId));
    }
    for (final planned in snapshot.plannedSessions) {
      final groupId = planned.groupId;
      _require(groupId == null || groups.contains(groupId));
    }
  }

  void _requireAll(Set<StudentId> present, Set<StudentId> students) {
    for (final id in present) {
      _require(students.contains(id));
    }
  }

  void _require(bool resolved) {
    if (!resolved) {
      throw const InvariantViolation(InvariantCode.backupInconsistent);
    }
  }
}
