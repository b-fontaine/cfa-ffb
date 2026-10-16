import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/failure.dart';

/// Chaque identifiant n'apparaît qu'une fois dans sa liste, et un élève n'a
/// qu'un marqueur de bloc acquis par bloc.
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
    _unique(snapshot.blockAcquisitions.map((a) => a.id.value));
    _unique(
      (snapshot.alertAcknowledgements ?? const <AlertAcknowledgement>[]).map(
        (a) => a.id.value,
      ),
    );
    // Au plus un marqueur par (élève, bloc).
    _unique(
      snapshot.blockAcquisitions.map(
        (a) => '${a.studentId.value.length}:${a.studentId.value}|${a.blockId}',
      ),
    );
  }

  void _unique(Iterable<String> ids) {
    final list = ids.toList();
    if (list.toSet().length != list.length) {
      throw const InvariantViolation(InvariantCode.backupInconsistent);
    }
  }
}
