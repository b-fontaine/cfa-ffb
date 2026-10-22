import 'package:billard_cfa/entities/exercise_result/data/in_memory_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/in_memory_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/in_memory_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/in_memory_assessment_repository.dart';
import 'package:billard_cfa/entities/run_progress/data/in_memory_run_progress_repository.dart';
import 'package:billard_cfa/entities/season/data/in_memory_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/in_memory_season_repository.dart';
import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/in_memory_session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/in_memory_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/in_memory_student_repository.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_marker_repository.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/features/manage_students/domain/local_student_erasure.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';

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

Future<RepositoryHarness> _open() async => RepositoryHarness(
  students: InMemoryStudentRepository(),
  groups: InMemoryGroupRepository(),
  seasons: InMemorySeasonRepository(),
  seasonArchives: InMemorySeasonArchiveRepository(),
  sessionRecords: InMemorySessionRecordRepository(),
  attempts: InMemoryAttemptRepository(),
  acquisitions: InMemoryAcquisitionRepository(),
  acknowledgements: InMemoryAcknowledgementRepository(),
  assessments: InMemoryAssessmentRepository(),
  sessions: InMemorySessionRepository(),
  settings: InMemorySettingsRepository(),
  runProgress: InMemoryRunProgressRepository(),
  unitOfWork: InMemoryUnitOfWork(),
  close: () async {},
);

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
  studentErasureContract('en mémoire', _openErasure);
  planningContract(
    'en mémoire',
    () async => (
      seasons: InMemorySeasonRepository(),
      groups: InMemoryGroupRepository(),
      sessions: InMemorySessionRepository(),
      records: InMemorySessionRecordRepository(),
      close: () async {},
    ),
  );
  repositoryContract('en mémoire', _open);
  repositoryWatchContract('en mémoire', _open);
  backupContract('en mémoire', _open);
  acquisitionContract(
    'en mémoire',
    () async =>
        (repository: InMemoryAcquisitionRepository(), close: () async {}),
  );
  acknowledgementContract(
    'en mémoire',
    () async =>
        (repository: InMemoryAcknowledgementRepository(), close: () async {}),
  );
  settingsContract(
    'en mémoire',
    () async => (repository: InMemorySettingsRepository(), close: () async {}),
  );
  seasonArchiveContract(
    'en mémoire',
    () async =>
        (repository: InMemorySeasonArchiveRepository(), close: () async {}),
  );
  runProgressContract(
    'en mémoire',
    () async =>
        (repository: InMemoryRunProgressRepository(), close: () async {}),
  );
  backupMarkerContract(
    'en mémoire',
    () async =>
        (repository: InMemoryBackupMarkerRepository(), close: () async {}),
  );
}
