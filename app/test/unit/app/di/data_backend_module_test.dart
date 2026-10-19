import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/di/data_backend_module.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/firestore_assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/drift_settings_repository.dart';
import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/firestore_world.dart';

class _Module extends DataBackendModule;

class _DriftSettings extends Mock implements DriftSettingsRepository;

class _DriftStudents extends Mock implements DriftStudentRepository;

class _DriftGroups extends Mock implements DriftGroupRepository;

class _DriftSeasons extends Mock implements DriftSeasonRepository;

class _DriftArchives extends Mock implements DriftSeasonArchiveRepository;

class _DriftSessions extends Mock implements DriftSessionRepository;

class _DriftRecords extends Mock implements DriftSessionRecordRepository;

class _DriftAttempts extends Mock implements DriftAttemptRepository;

class _DriftAcquisitions extends Mock implements DriftAcquisitionRepository;

class _DriftAssessments extends Mock implements DriftAssessmentRepository;

class _DriftAcknowledgements extends Mock
    implements DriftAcknowledgementRepository;

class _DriftUnitOfWork extends Mock implements DriftUnitOfWork;

class _User extends Mock implements CurrentUser;

void main() {
  final module = _Module();
  final club = FirestoreWorld().club;
  final user = _User();
  final tracker = SendTracker(InMemoryPendingWritesProbe());
  final drift = _DriftUnitOfWork();

  final settings = _DriftSettings();
  final students = _DriftStudents();
  final groups = _DriftGroups();
  final seasons = _DriftSeasons();
  final archives = _DriftArchives();
  final sessions = _DriftSessions();
  final records = _DriftRecords();
  final attempts = _DriftAttempts();
  final acquisitions = _DriftAcquisitions();
  final assessments = _DriftAssessments();
  final acknowledgements = _DriftAcknowledgements();

  /// Les 11 dépôts de données : chacun avec son instance drift et le type
  /// Firestore attendu.
  final repositories =
      <
        String,
        ({
          Object Function(DataBackendChoice) build,
          Object driftInstance,
          Matcher firestore,
        })
      >{
        'settings': (
          build: (c) => module.settingsRepository(c, settings, club),
          driftInstance: settings,
          firestore: isA<FirestoreSettingsRepository>(),
        ),
        'students': (
          build: (c) => module.studentRepository(c, students, club),
          driftInstance: students,
          firestore: isA<FirestoreStudentRepository>(),
        ),
        'groups': (
          build: (c) => module.groupRepository(c, groups, club),
          driftInstance: groups,
          firestore: isA<FirestoreGroupRepository>(),
        ),
        'seasons': (
          build: (c) => module.seasonRepository(c, seasons, club),
          driftInstance: seasons,
          firestore: isA<FirestoreSeasonRepository>(),
        ),
        'season archives': (
          build: (c) => module.seasonArchiveRepository(c, archives, club),
          driftInstance: archives,
          firestore: isA<FirestoreSeasonArchiveRepository>(),
        ),
        'sessions': (
          build: (c) => module.sessionRepository(c, sessions, club),
          driftInstance: sessions,
          firestore: isA<FirestoreSessionRepository>(),
        ),
        'session records': (
          build: (c) => module.sessionRecordRepository(c, records, club),
          driftInstance: records,
          firestore: isA<FirestoreSessionRecordRepository>(),
        ),
        'attempts': (
          build: (c) => module.attemptRepository(c, attempts, club),
          driftInstance: attempts,
          firestore: isA<FirestoreAttemptRepository>(),
        ),
        'acquisitions': (
          build: (c) => module.acquisitionRepository(c, acquisitions, club),
          driftInstance: acquisitions,
          firestore: isA<FirestoreAcquisitionRepository>(),
        ),
        'assessments': (
          build: (c) => module.assessmentRepository(c, assessments, club),
          driftInstance: assessments,
          firestore: isA<FirestoreAssessmentRepository>(),
        ),
        'acknowledgements': (
          build: (c) =>
              module.acknowledgementRepository(c, acknowledgements, club, user),
          driftInstance: acknowledgements,
          firestore: isA<FirestoreAcknowledgementRepository>(),
        ),
      };

  group('with DATA_BACKEND=firestore', () {
    const choice = DataBackendChoice(DataBackend.firestore);

    for (final entry in repositories.entries) {
      test('${entry.key} is the Firestore repository', () {
        expect(entry.value.build(choice), entry.value.firestore);
      });
    }

    test('the unit of work wraps the Firestore batch in the drift one', () {
      final work = module.unitOfWork(choice, drift, club, tracker);

      expect(work, isA<CompositeUnitOfWork>());
      final composite = work as CompositeUnitOfWork;
      expect(composite.outer, same(drift));
      expect(composite.inner, isA<FirestoreUnitOfWork>());
    });
  });

  group('with DATA_BACKEND=drift', () {
    const choice = DataBackendChoice(DataBackend.drift);

    for (final entry in repositories.entries) {
      test('${entry.key} is the very drift instance', () {
        expect(entry.value.build(choice), same(entry.value.driftInstance));
      });
    }

    test('the unit of work is the very drift one', () {
      expect(module.unitOfWork(choice, drift, club, tracker), same(drift));
    });
  });
}
