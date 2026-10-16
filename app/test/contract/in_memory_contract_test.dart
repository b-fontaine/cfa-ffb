import 'package:billard_cfa/entities/exercise_result/data/in_memory_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/in_memory_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/in_memory_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/in_memory_assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/in_memory_season_repository.dart';
import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/in_memory_session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/in_memory_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/in_memory_student_repository.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_marker_repository.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';

import 'acknowledgement_contract.dart';
import 'acquisition_contract.dart';
import 'backup_contract.dart';
import 'backup_marker_contract.dart';
import 'repository_contract.dart';
import 'repository_harness.dart';
import 'settings_contract.dart';

Future<RepositoryHarness> _open() async => RepositoryHarness(
  students: InMemoryStudentRepository(),
  groups: InMemoryGroupRepository(),
  seasons: InMemorySeasonRepository(),
  sessionRecords: InMemorySessionRecordRepository(),
  attempts: InMemoryAttemptRepository(),
  acquisitions: InMemoryAcquisitionRepository(),
  acknowledgements: InMemoryAcknowledgementRepository(),
  assessments: InMemoryAssessmentRepository(),
  sessions: InMemorySessionRepository(),
  settings: InMemorySettingsRepository(),
  unitOfWork: InMemoryUnitOfWork(),
  close: () async {},
);

void main() {
  repositoryContract('en mémoire', _open);
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
  backupMarkerContract(
    'en mémoire',
    () async =>
        (repository: InMemoryBackupMarkerRepository(), close: () async {}),
  );
}
