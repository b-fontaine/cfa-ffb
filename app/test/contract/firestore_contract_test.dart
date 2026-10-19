import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/drift_group_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/firestore_assessment_repository.dart';
import 'package:billard_cfa/entities/run_progress/data/drift_run_progress_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/drift_season_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/drift_settings_repository.dart';
import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/composite_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/drift_support.dart';
import 'acknowledgement_contract.dart';
import 'acquisition_contract.dart';
import 'backup_contract.dart';
import 'planning_contract.dart';
import 'repository_contract.dart';
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
SessionScope _directorScope() => SessionScope()
  ..signIn(const UserId('u-dir'))
  ..activate(const ClubId('c1'), Role.director);

ClubStore _openClub({SessionScope? scope}) {
  final firestore = FakeFirebaseFirestore();
  return ClubStore(
    FirestoreDocumentStore(
      access: FirestoreSdkAccess(firestore: () => firestore),
    ),
    scope ?? _directorScope(),
  );
}

/// Un club dont la saison, le groupe `g1` et les fiches `s1`, `s2` existent :
/// ce que les données d'un élève (bloc acquis, acquittement) exigent d'abord
/// pour porter leur groupe et leur saison.
Future<ClubStore> _openOwnedClub({SessionScope? scope}) async {
  final club = _openClub(scope: scope);
  await FirestoreSeasonRepository(club).save(
    Season(
      id: const SeasonId('season'),
      label: '2026-2027',
      startDate: DateTime(2026, 9),
      endDate: DateTime(2027, 6, 30),
    ),
  );
  final students = FirestoreStudentRepository(club);
  var group = Group(
    id: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    name: 'Jeunes',
    audience: Audience.children,
  );
  for (final id in ['s1', 's2']) {
    await students.save(
      Student.enroll(
        id: StudentId(id),
        firstName: id,
        audience: Audience.children,
        since: DateTime(2026, 9),
      ),
    );
    group = group.admit(
      studentId: StudentId(id),
      studentAudience: Audience.children,
      from: DateTime(2026, 9),
    );
  }
  await FirestoreGroupRepository(club).save(group);
  return club;
}

/// Laisse le faux Firestore finir d'appliquer le lot après l'unité de travail.
///
/// Le SDK applique un lot à son cache local **dès l'appel** : une lecture
/// faite ensuite le voit (appels ordonnés). `fake_cloud_firestore` l'applique
/// en quelques tours de la file d'événements : sans attendre l'accusé (la
/// composite ne l'attend plus), une lecture immédiate pourrait le manquer.
/// Écart du faux, pas du comportement visé (voir `testing.md`).
class _SettlingUnitOfWork implements UnitOfWork {
  _SettlingUnitOfWork(this._inner);

  final UnitOfWork _inner;

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    final result = await _inner.run(body);
    await pumpEventQueue();
    return result;
  }
}

/// Tous les dépôts de données sur le faux Firestore (le montage de production
/// avec `DATA_BACKEND=firestore`, `DataBackendModule`) : seul `runProgress`
/// reste local (ADR 0020), et l'unité de travail est la composite (drift
/// enveloppe le lot Firestore, validé localement sans attendre le serveur). Le
/// contrat complet des repositories y est joué ; ses limites sont dites dans
/// `testing.md`.
Future<RepositoryHarness> _openAll() async {
  final scope = _directorScope();
  final club = _openClub(scope: scope);
  final db = openMemoryDatabase();
  return RepositoryHarness(
    students: FirestoreStudentRepository(club),
    groups: FirestoreGroupRepository(club),
    seasons: FirestoreSeasonRepository(club),
    seasonArchives: FirestoreSeasonArchiveRepository(club),
    sessionRecords: FirestoreSessionRecordRepository(club),
    attempts: FirestoreAttemptRepository(club),
    acquisitions: FirestoreAcquisitionRepository(club),
    acknowledgements: FirestoreAcknowledgementRepository(club, scope),
    assessments: FirestoreAssessmentRepository(club),
    sessions: FirestoreSessionRepository(club),
    settings: FirestoreSettingsRepository(club),
    runProgress: DriftRunProgressRepository(db),
    unitOfWork: _SettlingUnitOfWork(
      CompositeUnitOfWork(
        outer: DriftUnitOfWork(db),
        inner: FirestoreUnitOfWork(
          club,
          tracker: SendTracker(InMemoryPendingWritesProbe()),
        ),
      ),
    ),
    close: db.close,
  );
}

void main() {
  repositoryContract(
    'Firestore (faux en mémoire)',
    _openAll,
    traits: const ContractTraits(
      insertionOrder: false,
      requiresOwners: true,
      sessionsNeedGroup: true,
      addReplaces: false,
    ),
  );

  backupImportUnsupportedContract(
    'Firestore (faux en mémoire, montage de production)',
    _openMixedSource,
    _openAll,
  );

  backupImportWithoutSittingContract(
    'Firestore (faux en mémoire, montage de production)',
    _openMixedSource,
    _openAll,
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

  acquisitionContract(
    'Firestore (faux en mémoire)',
    () async => (
      repository: FirestoreAcquisitionRepository(await _openOwnedClub()),
      close: () async {},
    ),
  );

  acknowledgementContract('Firestore (faux en mémoire)', () async {
    final scope = _directorScope();
    return (
      repository: FirestoreAcknowledgementRepository(
        await _openOwnedClub(scope: scope),
        scope,
      ),
      close: () async {},
    );
  });

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
