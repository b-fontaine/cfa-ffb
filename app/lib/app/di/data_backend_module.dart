import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/firestore_club_import_store.dart';
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
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/unsupported_club_import_store.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:injectable/injectable.dart';

/// Aiguillage des dépôts de données entre Firestore (défaut depuis la bascule
/// du 2026-10-21) et drift, explicite (ADR 0024, décision 28 amendée). Le
/// réglage est `DATA_BACKEND` (voir [DataBackend]) ; les tests et les
/// scénarios BDD (`Environment.test`) gardent leurs dépôts en mémoire et
/// n'en dépendent pas (leur backend est fixé ici, pas le défaut du build).
@module
abstract class DataBackendModule {
  @Environment(Environment.prod)
  @singleton
  DataBackendChoice dataBackend(DataBackendRequest request) =>
      DataBackendChoice(request.resolved);

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
