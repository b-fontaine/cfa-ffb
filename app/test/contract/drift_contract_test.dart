import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/run_progress/data/drift_run_progress_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/drift_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/features/backup_data/data/drift_backup_marker_repository.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/features/manage_students/domain/local_student_erasure.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/drift_support.dart';
import 'acknowledgement_contract.dart';
import 'acquisition_contract.dart';
import 'backup_contract.dart';
import 'backup_marker_contract.dart';
import 'planning_contract.dart';
import 'repository_contract.dart';
import 'repository_harness.dart';
import 'repository_watch_contract.dart';
import 'run_progress_contract.dart';
import 'season_archive_contract.dart';
import 'settings_contract.dart';
import 'student_erasure_contract.dart';

Future<RepositoryHarness> _open() async {
  final db = openMemoryDatabase();
  final clock = TickingClock();
  return RepositoryHarness(
    students: DriftStudentRepository(db, clock),
    groups: DriftGroupRepository(db, clock),
    seasons: DriftSeasonRepository(db, clock),
    seasonArchives: DriftSeasonArchiveRepository(db),
    sessionRecords: DriftSessionRecordRepository(db, clock),
    attempts: DriftAttemptRepository(db, clock),
    acquisitions: DriftAcquisitionRepository(db, clock),
    acknowledgements: DriftAcknowledgementRepository(db, clock),
    assessments: DriftAssessmentRepository(db, clock),
    sessions: DriftSessionRepository(db, clock),
    settings: DriftSettingsRepository(db, clock),
    runProgress: DriftRunProgressRepository(db),
    unitOfWork: DriftUnitOfWork(db),
    close: db.close,
  );
}

Future<ErasureSetup> _openErasure() async {
  final r = await _open();
  return (
    erasure: LocalStudentErasure(
      EraseStudent(
        r.students,
        r.groups,
        r.sessionRecords,
        r.attempts,
        r.assessments,
        r.acquisitions,
        r.acknowledgements,
        r.runProgress,
        r.sessions,
        r.unitOfWork,
      ),
      r.students,
    ),
    repositories: r,
    close: r.close,
  );
}

void main() {
  studentErasureContract('drift (SQLite)', _openErasure);
  planningContract('drift (SQLite)', () async {
    final db = openMemoryDatabase();
    final clock = TickingClock();
    return (
      seasons: DriftSeasonRepository(db, clock),
      groups: DriftGroupRepository(db, clock),
      sessions: DriftSessionRepository(db, clock),
      records: DriftSessionRecordRepository(db, clock),
      close: db.close,
    );
  });
  repositoryContract('drift (SQLite)', _open);
  repositoryWatchContract('drift (SQLite)', _open);
  backupContract('drift (SQLite)', _open);
  acquisitionContract('drift (SQLite)', () async {
    final db = openMemoryDatabase();
    return (
      repository: DriftAcquisitionRepository(db, TickingClock()),
      close: db.close,
    );
  });
  acknowledgementContract('drift (SQLite)', () async {
    final db = openMemoryDatabase();
    return (
      repository: DriftAcknowledgementRepository(db, TickingClock()),
      close: db.close,
    );
  });
  settingsContract('drift (SQLite)', () async {
    final db = openMemoryDatabase();
    return (
      repository: DriftSettingsRepository(db, TickingClock()),
      close: db.close,
    );
  });
  seasonArchiveContract('drift (SQLite)', () async {
    final db = openMemoryDatabase();
    return (repository: DriftSeasonArchiveRepository(db), close: db.close);
  });
  runProgressContract('drift (SQLite)', () async {
    final db = openMemoryDatabase();
    return (repository: DriftRunProgressRepository(db), close: db.close);
  });
  backupMarkerContract('drift (SQLite)', () async {
    final db = openMemoryDatabase();
    return (repository: DriftBackupMarkerRepository(db), close: db.close);
  });
}
