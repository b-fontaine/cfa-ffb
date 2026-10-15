import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/features/backup_data/data/drift_backup_marker_repository.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/drift_support.dart';
import 'acquisition_contract.dart';
import 'backup_contract.dart';
import 'backup_marker_contract.dart';
import 'repository_contract.dart';
import 'repository_harness.dart';

Future<RepositoryHarness> _open() async {
  final db = openMemoryDatabase();
  final clock = TickingClock();
  return RepositoryHarness(
    students: DriftStudentRepository(db, clock),
    groups: DriftGroupRepository(db, clock),
    seasons: DriftSeasonRepository(db, clock),
    sessionRecords: DriftSessionRecordRepository(db, clock),
    attempts: DriftAttemptRepository(db, clock),
    acquisitions: DriftAcquisitionRepository(db, clock),
    assessments: DriftAssessmentRepository(db, clock),
    sessions: DriftSessionRepository(db, clock),
    unitOfWork: DriftUnitOfWork(db),
    close: db.close,
  );
}

void main() {
  repositoryContract('drift (SQLite)', _open);
  backupContract('drift (SQLite)', _open);
  acquisitionContract('drift (SQLite)', () async {
    final db = openMemoryDatabase();
    return (
      repository: DriftAcquisitionRepository(db, TickingClock()),
      close: db.close,
    );
  });
  backupMarkerContract('drift (SQLite)', () async {
    final db = openMemoryDatabase();
    return (repository: DriftBackupMarkerRepository(db), close: db.close);
  });
}
