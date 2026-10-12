import 'package:billard_cfa/entities/exercise_result/data/in_memory_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/in_memory_assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/in_memory_season_repository.dart';
import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/in_memory_session_record_repository.dart';
import 'package:billard_cfa/entities/student/data/in_memory_student_repository.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';

import 'backup_contract.dart';
import 'repository_contract.dart';
import 'repository_harness.dart';

Future<RepositoryHarness> _open() async => RepositoryHarness(
  students: InMemoryStudentRepository(),
  groups: InMemoryGroupRepository(),
  seasons: InMemorySeasonRepository(),
  sessionRecords: InMemorySessionRecordRepository(),
  attempts: InMemoryAttemptRepository(),
  assessments: InMemoryAssessmentRepository(),
  sessions: InMemorySessionRepository(),
  unitOfWork: InMemoryUnitOfWork(),
  close: () async {},
);

void main() {
  repositoryContract('en mémoire', _open);
  backupContract('en mémoire', _open);
}
