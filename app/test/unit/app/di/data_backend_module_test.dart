import 'package:billard_cfa/app/club_student_purge.dart';
import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/di/data_backend_module.dart';
import 'package:billard_cfa/app/firestore_club_import_store.dart';
import 'package:billard_cfa/app/firestore_operation_store.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/firestore_assessment_repository.dart';
import 'package:billard_cfa/entities/run_progress/domain/run_progress_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/drift_settings_repository.dart';
import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/unsupported_club_import_store.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/club_season_closing.dart';
import 'package:billard_cfa/features/close_season/domain/local_season_closing.dart';
import 'package:billard_cfa/features/close_season/domain/season_closing.dart';
import 'package:billard_cfa/features/manage_students/domain/club_student_erasure.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/features/manage_students/domain/local_student_erasure.dart';
import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/operations/unsupported_operations.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/firestore_world.dart';
import '../../../support/import_world.dart';
import '../../../support/realistic_backup.dart';

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

class _EraseStudent extends Mock implements EraseStudent;

class _CloseSeason extends Mock implements CloseSeason;

class _Scope extends Mock implements ActiveClubScope;

class _Ledger extends Mock implements ImportDailyLedger;

class _Students extends Mock implements StudentRepository;

class _Groups extends Mock implements GroupRepository;

class _Seasons extends Mock implements SeasonRepository;

class _Records extends Mock implements SessionRecordRepository;

class _Attempts extends Mock implements AttemptRepository;

class _Planned extends Mock implements SessionRepository;

class _Archives extends Mock implements SeasonArchiveRepository;

class _RunProgress extends Mock implements RunProgressRepository;

/// Les opérations reprenables (FB8) : le montage de chaque backend.
void _operations(_Module module, ClubStore club, CurrentUser user) {
  final scope = _Scope();
  final eraseStudent = _EraseStudent();
  final closeSeason = _CloseSeason();
  final students = _Students();
  final groups = _Groups();
  final seasons = _Seasons();
  final records = _Records();
  final attempts = _Attempts();
  final planned = _Planned();
  final archives = _Archives();
  final runProgress = _RunProgress();
  final ledger = module.dailyWriteLedger(_Ledger());

  StudentErasure erasure(DataBackendChoice choice) {
    final store = module.operationStore(choice, club, user);
    final purge = module.studentPurge(choice, club, runProgress);
    return module.studentErasure(
      choice,
      eraseStudent,
      students,
      module.operationRunner(store, ledger),
      purge,
      scope,
    );
  }

  SeasonClosing closing(DataBackendChoice choice) {
    final store = module.operationStore(choice, club, user);
    return module.seasonClosing(
      choice,
      closeSeason,
      module.operationRunner(store, ledger),
      store,
      module.studentPurge(choice, club, runProgress),
      scope,
      seasons,
      groups,
      students,
      records,
      attempts,
      planned,
      archives,
    );
  }

  group('operations with DATA_BACKEND=firestore', () {
    const choice = DataBackendChoice(DataBackend.firestore);

    test('the operation marker and the purge are the club ones', () {
      expect(
        module.operationStore(choice, club, user),
        isA<FirestoreOperationStore>(),
      );
      expect(
        module.studentPurge(choice, club, runProgress),
        isA<ClubStudentPurge>(),
      );
    });

    test('erasing a student goes through resumable lots', () {
      expect(erasure(choice), isA<ClubStudentErasure>());
    });

    test('closing a season goes through resumable lots', () {
      final result = closing(choice);

      expect(result, isA<ClubSeasonClosing>());
      expect(result.synchronized, isTrue);
    });

    test('the daily write count is the one of the import', () async {
      final shared = _Ledger();
      when(shared.spentToday).thenAnswer((_) async => 42);
      when(() => shared.add(any())).thenAnswer((_) async {});
      final adapter = module.dailyWriteLedger(shared);

      expect(await adapter.spentToday(), 42);
      await adapter.add(7);
      verify(() => shared.add(7)).called(1);
    });
  });

  group('operations with DATA_BACKEND=drift', () {
    const choice = DataBackendChoice(DataBackend.drift);

    test('nothing can write operation markers', () async {
      final store = module.operationStore(choice, club, user);

      expect(store, isA<UnsupportedOperationStore>());
      expect(
        module.studentPurge(choice, club, runProgress),
        isA<UnsupportedStudentPurge>(),
      );
      await expectLater(store.readMarker('k'), throwsA(isA<ServiceFailure>()));
    });

    test('erasing a student stays local, in one unit of work', () {
      expect(erasure(choice), isA<LocalStudentErasure>());
    });

    test('closing a season stays local, in one unit of work', () {
      final result = closing(choice);

      expect(result, isA<LocalSeasonClosing>());
      expect(result.synchronized, isFalse);
    });
  });
}

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

  _operations(module, club, user);

  group('with DATA_BACKEND=firestore', () {
    const choice = DataBackendChoice(DataBackend.firestore);

    for (final entry in repositories.entries) {
      test('${entry.key} is the Firestore repository', () {
        expect(entry.value.build(choice), entry.value.firestore);
      });
    }

    test('the club import writes to Firestore', () {
      expect(
        module.clubImportStore(choice, club, user),
        isA<FirestoreClubImportStore>(),
      );
    });

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

    // Tous les dépôts lisent drift : un import qui écrirait dans Firestore des
    // données que l'application ne relirait pas est refusé, sans rien écrire.
    test(
      'the club import is unsupported: nothing is prepared or written',
      () async {
        final store = module.clubImportStore(choice, club, user);
        expect(store, isA<UnsupportedClubImportStore>());
        final world = ImportWorld.open()..act(Role.director);
        final result = await world.prepareUseCaseWith(store)(
          RealisticBackup().content,
        );
        expect(
          result,
          isA<Err<Object>>().having(
            (e) => e.failure,
            'failure',
            isA<ServiceFailure>().having(
              (f) => f.code,
              'code',
              ServiceFailureCode.unsupported,
            ),
          ),
        );
      },
    );
  });

  group('without DATA_BACKEND (default of the production build)', () {
    final choice = DataBackendChoice(DataBackend.resolve(''));

    // Le module ne reçoit aucun rôle (aucun aiguillage par rôle, décision du
    // 2026-10-19) : la preuve est un défaut drift unique, identique pour tout
    // compte, l'espace famille compris. Le graphe de production exact est
    // vérifié par `production_graph_test`.
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
