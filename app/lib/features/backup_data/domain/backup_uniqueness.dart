import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/failure.dart';

/// Chaque identifiant n'apparaît qu'une fois dans sa liste.
class BackupUniqueness {
  const BackupUniqueness();

  void check(BackupSnapshot snapshot) {
    _unique(snapshot.seasons.map((s) => s.id.value));
    _unique(snapshot.students.map((s) => s.id.value));
    _unique(snapshot.groups.map((g) => g.id.value));
    _unique(snapshot.sessionRecords.map((s) => s.id.value));
    _unique(snapshot.attempts.map((a) => a.id.value));
    _unique(snapshot.assessments.map((a) => a.id.value));
    _unique(snapshot.plannedSessions.map((s) => s.id));
  }

  void _unique(Iterable<String> ids) {
    final list = ids.toList();
    if (list.toSet().length != list.length) {
      throw const InvariantViolation(InvariantCode.backupInconsistent);
    }
  }
}
