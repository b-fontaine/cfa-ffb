import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/run_progress/data/drift_run_progress_repository.dart';
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
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import '../support/drift_support.dart';
import 'backup_contract.dart';
import 'planning_contract.dart';
import 'repository_harness.dart';
import 'season_archive_contract.dart';
import 'settings_contract.dart';
import 'student_group_contract.dart';
import 'unit_of_work_contract.dart';

/// Un club `c1` dirigé par un directeur, sur un **faux Firestore en mémoire**
/// (`fake_cloud_firestore`) derrière le vrai `FirestoreDocumentStore` et le
/// vrai `FirestoreSdkAccess`.
///
/// Ce que cela prouve : les dépôts Firestore tiennent le même contrat que
/// drift et la mémoire, avec la traduction réelle des valeurs (dates, listes,
/// date du serveur) et des requêtes. Ce que cela NE prouve PAS : les règles de
/// sécurité, les index, les chemins réels, les quotas, le hors ligne (le faux
/// n'en applique aucun) : voir `docs/engineering/testing.md`, section FB4, et
/// `scripts/rules_test/repositories.test.mjs` pour le pendant contre
/// l'émulateur.
ClubStore _openClub() {
  final scope = SessionScope()
    ..signIn(const UserId('u-dir'))
    ..activate(const ClubId('c1'), Role.director);
  final firestore = FakeFirebaseFirestore();
  return ClubStore(
    FirestoreDocumentStore(
      access: FirestoreSdkAccess(firestore: () => firestore),
    ),
    scope,
  );
}

/// Le montage de production avec `DATA_BACKEND=firestore` : les dépôts migrés
/// (FB4) sur le faux Firestore, les autres sur drift, une unité de travail
/// composite (`DataBackendModule`).
Future<RepositoryHarness> _openMixed() async {
  final club = _openClub();
  final db = openMemoryDatabase();
  final clock = TickingClock();
  return RepositoryHarness(
    students: FirestoreStudentRepository(club),
    groups: FirestoreGroupRepository(club),
    seasons: FirestoreSeasonRepository(club),
    seasonArchives: FirestoreSeasonArchiveRepository(club),
    sessionRecords: FirestoreSessionRecordRepository(club),
    attempts: DriftAttemptRepository(db, clock),
    acquisitions: DriftAcquisitionRepository(db, clock),
    acknowledgements: DriftAcknowledgementRepository(db, clock),
    assessments: DriftAssessmentRepository(db, clock),
    sessions: FirestoreSessionRepository(club),
    settings: FirestoreSettingsRepository(club),
    runProgress: DriftRunProgressRepository(db),
    unitOfWork: CompositeUnitOfWork(
      outer: DriftUnitOfWork(db),
      inner: FirestoreUnitOfWork(club),
    ),
    close: db.close,
  );
}

void main() {
  backupImportUnsupportedContract(
    'Firestore (faux en mémoire)',
    _openMixedSource,
    _openMixed,
  );

  studentGroupContract('Firestore (faux en mémoire)', () async {
    final club = _openClub();
    return (
      students: FirestoreStudentRepository(club),
      groups: FirestoreGroupRepository(club),
      close: () async {},
    );
  });

  unitOfWorkContract('Firestore (faux en mémoire)', () async {
    final club = _openClub();
    return (
      club: club,
      unitOfWork: FirestoreUnitOfWork(club),
      close: () async {},
    );
  }, storeRollsBack: false);

  planningContract('Firestore (faux en mémoire)', () async {
    final club = _openClub();
    return (
      seasons: FirestoreSeasonRepository(club),
      groups: FirestoreGroupRepository(club),
      sessions: FirestoreSessionRepository(club),
      records: FirestoreSessionRecordRepository(club),
      close: () async {},
    );
  }, isolatedTransactions: false);

  seasonArchiveContract(
    'Firestore (faux en mémoire)',
    () async => (
      repository: FirestoreSeasonArchiveRepository(_openClub()),
      close: () async {},
    ),
  );

  settingsContract(
    'Firestore (faux en mémoire)',
    () async => (
      repository: FirestoreSettingsRepository(_openClub()),
      close: () async {},
    ),
  );
}

/// Une source de sauvegarde : des dépôts drift seuls (le contenu à exporter).
Future<RepositoryHarness> _openMixedSource() async {
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
