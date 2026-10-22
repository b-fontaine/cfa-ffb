import 'package:billard_cfa/app/club_student_purge.dart';
import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/firestore_club_import_store.dart';
import 'package:billard_cfa/app/firestore_operation_store.dart';
import 'package:billard_cfa/app/import_daily_ledger_adapter.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/firestore_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
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
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/data/existing_student_directory.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/data/store_student_directory.dart';
import 'package:billard_cfa/entities/student/domain/student_directory.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/unsupported_club_import_store.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/club_season_closing.dart';
import 'package:billard_cfa/features/close_season/domain/local_season_closing.dart';
import 'package:billard_cfa/features/close_season/domain/season_closing.dart';
import 'package:billard_cfa/features/close_season/domain/season_closure_operation.dart';
import 'package:billard_cfa/features/manage_students/domain/club_student_erasure.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/features/manage_students/domain/local_student_erasure.dart';
import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';
import 'package:billard_cfa/shared/lib/operations/unsupported_operations.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:injectable/injectable.dart';

/// Aiguillage des dépôts de données entre drift (défaut) et Firestore (ADR
/// 0024, décision 28). Les dépôts migrés **un lot à la fois** y entrent ;
/// les autres restent drift. Le réglage est `DATA_BACKEND` (voir
/// [DataBackend]) ; les tests et les scénarios BDD (`Environment.test`)
/// gardent leurs dépôts en mémoire et n'en dépendent pas.
@module
abstract class DataBackendModule {
  @Environment(Environment.prod)
  @singleton
  DataBackendChoice dataBackend() => DataBackendChoice(DataBackend.fromBuild());

  /// Les tests et les scénarios BDD tournent sur le backend local (les
  /// scénarios qui parlent à Firestore le remplacent, comme leurs dépôts).
  @Environment(Environment.test)
  @singleton
  DataBackendChoice testDataBackend() =>
      const DataBackendChoice(DataBackend.drift);

  @Environment(Environment.prod)
  @lazySingleton
  SettingsRepository settingsRepository(
    DataBackendChoice choice,
    DriftSettingsRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreSettingsRepository(club),
  );

  /// Sous drift, les fiches sont locales et publiées vers le club à la
  /// première invitation ; sous Firestore elles existent déjà et l'annuaire ne
  /// crée jamais de fiche (une fiche effacée ne doit pas revenir).
  @Environment(Environment.prod)
  @lazySingleton
  StudentDirectory studentDirectory(
    DataBackendChoice choice,
    DocumentStore store,
  ) => choice.backend.choose(
    drift: () => StoreStudentDirectory(store),
    firestore: () => ExistingStudentDirectory(store),
  );

  @Environment(Environment.prod)
  @lazySingleton
  StudentRepository studentRepository(
    DataBackendChoice choice,
    DriftStudentRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreStudentRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  GroupRepository groupRepository(
    DataBackendChoice choice,
    DriftGroupRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreGroupRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  SeasonRepository seasonRepository(
    DataBackendChoice choice,
    DriftSeasonRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreSeasonRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  SeasonArchiveRepository seasonArchiveRepository(
    DataBackendChoice choice,
    DriftSeasonArchiveRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreSeasonArchiveRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  SessionRepository sessionRepository(
    DataBackendChoice choice,
    DriftSessionRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreSessionRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  SessionRecordRepository sessionRecordRepository(
    DataBackendChoice choice,
    DriftSessionRecordRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreSessionRecordRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  AttemptRepository attemptRepository(
    DataBackendChoice choice,
    DriftAttemptRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreAttemptRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  AcquisitionRepository acquisitionRepository(
    DataBackendChoice choice,
    DriftAcquisitionRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreAcquisitionRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  AssessmentRepository assessmentRepository(
    DataBackendChoice choice,
    DriftAssessmentRepository drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreAssessmentRepository(club),
  );

  @Environment(Environment.prod)
  @lazySingleton
  AcknowledgementRepository acknowledgementRepository(
    DataBackendChoice choice,
    DriftAcknowledgementRepository drift,
    ClubStore club,
    CurrentUser user,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => FirestoreAcknowledgementRepository(club, user),
  );

  /// L'import d'une sauvegarde dans le club (FB7) : n'écrit que dans Firestore.
  /// Avec drift (le défaut), tous les dépôts lisent drift : l'import est refusé
  /// (`unsupported`) plutôt que d'écrire des données que l'application ne
  /// relirait pas.
  @Environment(Environment.prod)
  @lazySingleton
  ClubImportStore clubImportStore(
    DataBackendChoice choice,
    ClubStore club,
    CurrentUser user,
  ) => choice.backend.choose(
    drift: () => const UnsupportedClubImportStore(),
    firestore: () => FirestoreClubImportStore(club, user),
  );

  /// Le magasin des opérations reprenables (FB8) : le marqueur d'opération du
  /// club. Avec drift, l'effacement et la clôture restent locaux : refusé.
  @Environment(Environment.prod)
  @lazySingleton
  OperationStore operationStore(
    DataBackendChoice choice,
    ClubStore club,
    CurrentUser user,
  ) => choice.backend.choose(
    drift: () => const UnsupportedOperationStore(),
    firestore: () => FirestoreOperationStore(club, user),
  );

  @Environment(Environment.prod)
  @lazySingleton
  StudentPurge studentPurge(
    DataBackendChoice choice,
    ClubStore club,
    RunProgressRepository runProgress,
  ) => choice.backend.choose(
    drift: () => const UnsupportedStudentPurge(),
    firestore: () => ClubStudentPurge(club, runProgress),
  );

  /// Le plafond du jour, partagé avec l'import d'une sauvegarde.
  @Environment(Environment.prod)
  @lazySingleton
  DailyWriteLedger dailyWriteLedger(ImportDailyLedger ledger) =>
      ImportDailyLedgerAdapter(ledger);

  @Environment(Environment.prod)
  @lazySingleton
  OperationRunner operationRunner(
    OperationStore store,
    DailyWriteLedger ledger,
  ) => OperationRunner(store, ledger);

  /// L'effacement d'un élève : sur l'appareil avec drift (une unité de
  /// travail), par lots reprenables avec Firestore (FB8).
  @Environment(Environment.prod)
  @lazySingleton
  StudentErasure studentErasure(
    DataBackendChoice choice,
    EraseStudent erase,
    StudentRepository students,
    OperationRunner runner,
    StudentPurge purge,
    ActiveClubScope scope,
  ) => choice.backend.choose(
    drift: () => LocalStudentErasure(erase, students),
    firestore: () => ClubStudentErasure(runner, purge, scope),
  );

  /// La clôture d'une saison : sur l'appareil avec drift, par lots
  /// reprenables avec Firestore (FB8).
  @Environment(Environment.prod)
  @lazySingleton
  SeasonClosing seasonClosing(
    DataBackendChoice choice,
    CloseSeason close,
    OperationRunner runner,
    OperationStore store,
    StudentPurge purge,
    ActiveClubScope scope,
    SeasonRepository seasons,
    GroupRepository groups,
    StudentRepository students,
    SessionRecordRepository records,
    AttemptRepository attempts,
    SessionRepository sessions,
    SeasonArchiveRepository archives,
  ) => choice.backend.choose(
    drift: () => LocalSeasonClosing(close),
    firestore: () => ClubSeasonClosing(
      runner,
      store,
      purge,
      ClosureRepositories(
        seasons: seasons,
        groups: groups,
        students: students,
        sessionRecords: records,
        attempts: attempts,
        plannedSessions: sessions,
        archives: archives,
      ),
      scope,
    ),
  );

  @Environment(Environment.test)
  @lazySingleton
  StudentErasure testStudentErasure(
    EraseStudent erase,
    StudentRepository students,
  ) => LocalStudentErasure(erase, students);

  @Environment(Environment.test)
  @lazySingleton
  SeasonClosing testSeasonClosing(CloseSeason close) =>
      LocalSeasonClosing(close);

  /// Unité de travail : celle de drift ; avec Firestore, drift enveloppe le lot
  /// Firestore, validé localement **sans attendre le serveur** (voir
  /// [CompositeUnitOfWork] ; l'envoi est suivi par `SendStatus`).
  @Environment(Environment.prod)
  @lazySingleton
  UnitOfWork unitOfWork(
    DataBackendChoice choice,
    DriftUnitOfWork drift,
    ClubStore club,
    SendTracker tracker,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () => CompositeUnitOfWork(
      outer: drift,
      inner: FirestoreUnitOfWork(club, tracker: tracker),
    ),
  );
}
