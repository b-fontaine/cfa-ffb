import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
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
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
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

  /// Unité de travail : celle de drift ; avec Firestore, drift enveloppe le lot
  /// Firestore (voir [CompositeUnitOfWork]).
  @Environment(Environment.prod)
  @lazySingleton
  UnitOfWork unitOfWork(
    DataBackendChoice choice,
    DriftUnitOfWork drift,
    ClubStore club,
  ) => choice.backend.choose(
    drift: () => drift,
    firestore: () =>
        CompositeUnitOfWork(outer: drift, inner: FirestoreUnitOfWork(club)),
  );
}
