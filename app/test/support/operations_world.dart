import 'package:billard_cfa/app/club_student_purge.dart';
import 'package:billard_cfa/app/firestore_operation_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/firestore_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/run_progress/data/in_memory_run_progress_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/club_season_closing.dart';
import 'package:billard_cfa/features/close_season/domain/season_closing.dart';
import 'package:billard_cfa/features/close_season/domain/season_closure_operation.dart';
import 'package:billard_cfa/features/manage_students/domain/club_student_erasure.dart';
import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import 'club_seed.dart';
import 'domain_world.dart';
import 'fixed_clock.dart';
import 'in_memory_write_ledger.dart';

/// Un **faux serveur** devant le stock en mémoire, qui applique ce que les
/// règles Firestore imposent aux opérations reprenables (FB8 ;
/// `scripts/rules_test/operations.test.mjs` les joue pour de vrai) :
///
/// - **le marqueur** `clubs/{c}/operations/{key}_{uid}` (propre à son auteur) :
///   création à `done == 1`, avancement d'**exactement un** lot et d'au plus
///   une étape, suppression par le dernier lot ; aucun champ hors liste ;
/// - **une donnée nouvelle** (passage, bloc acquis, bilan, acquittement) sur
///   une fiche absente ou en cours d'effacement (`erasing`) est refusée ;
/// - **`erasing` est irréversible** ;
/// - **au plus 400 écritures par lot** (une opération en envoie 400 au plus,
///   marqueur compris) ;
/// - un lot qui touche le marqueur d'un autre auteur est refusé.
///
/// Il simule aussi les coupures : [failAfterBatches] (le réseau tombe avant le
/// lot suivant) et [dropAckAt] (le lot est appliqué mais l'accusé est perdu).
class OperationsRulesStore implements DocumentStore {
  OperationsRulesStore(this.inner);

  final InMemoryDocumentStore inner;

  /// Lots appliqués et écritures acceptées (assertions).
  int appliedBatches = 0;
  int appliedWrites = 0;

  /// Chaque lot appliqué : ses chemins (ordre des écritures), pour vérifier
  /// l'ordre des étapes.
  final List<List<String>> log = [];

  /// Après ce nombre de lots appliqués, le lot suivant échoue (`unavailable`)
  /// **sans** être appliqué.
  int? failAfterBatches;

  /// Le lot d'indice [dropAckAt] (à partir de 0) est appliqué, puis le réseau
  /// tombe avant l'accusé : l'appelant reçoit `unavailable`.
  int? dropAckAt;

  /// Attend avant d'appliquer chaque lot (un serveur lent, deux appareils).
  Future<void> Function()? beforeCommit;

  /// Appelé **après** chaque lot appliqué, avec le nombre de lots appliqués :
  /// un autre appareil écrit entre deux lots de l'opération.
  Future<void> Function(int appliedBatches)? afterCommit;

  /// Le compte connecté (`request.auth.uid`) : son marqueur seul est permis.
  String? authUid;

  /// Les règles refusent tout : le rôle courant n'a aucun droit (enseignant).
  bool denyAll = false;

  DateTime serverStart = DateTime.utc(2026, 10, 12, 9);

  static const _studentData = [
    '/attempts/',
    '/acquisitions/',
    '/assessments/',
    '/acknowledgements/',
  ];
  static const _markerKeys = {
    'operationId',
    'kind',
    'done',
    'stage',
    'role',
    'createdBy',
    'startedAt',
    'updatedAt',
    'seasonId',
    'closedOn',
    'prepareNext',
    'dropPlanned',
  };

  @override
  Future<void> commit(List<WriteOp> operations) async {
    await beforeCommit?.call();
    final failAfter = failAfterBatches;
    if (failAfter != null && appliedBatches >= failAfter) {
      throw const StoreFailure(StoreFailureCode.unavailable, 'coupure');
    }
    _validate(operations);
    final stamp = serverStart.add(Duration(seconds: appliedBatches));
    inner.serverNow = () => stamp;
    await inner.commit(operations);
    log.add([for (final op in operations) op.path]);
    appliedBatches++;
    appliedWrites += operations.length;
    await afterCommit?.call(appliedBatches);
    if (dropAckAt == appliedBatches - 1) {
      dropAckAt = null;
      throw const StoreFailure(StoreFailureCode.unavailable, 'accusé perdu');
    }
  }

  void _validate(List<WriteOp> operations) {
    Never deny(String why) =>
        throw StoreFailure(StoreFailureCode.permissionDenied, why);
    if (denyAll) deny('rôle sans droit');
    if (operations.length > 400) deny('plus de 400 écritures');
    final uid = authUid;
    final markers = operations.where((o) => o.path.contains('/operations/'));
    if (markers.length > 1) deny('un lot porte au plus un marqueur');
    for (final marker in markers) {
      if (uid != null && !marker.path.endsWith('_$uid')) {
        deny("marqueur d'un autre auteur");
      }
      final current = inner.read(marker.path);
      switch (marker) {
        case SetOp(:final fields):
          if (current != null || fields['done'] != 1) deny('création');
          if ((fields['stage']! as int) > 1) deny('étape de départ');
          if (!fields.keys.every(_markerKeys.contains)) deny('champ en trop');
          if (fields['createdBy'] != uid) deny('auteur');
        case UpdateOp(:final fields):
          if (current == null) {
            throw StoreFailure(StoreFailureCode.notFound, marker.path);
          }
          final stage = current['stage']! as int;
          if (fields['done'] != (current['done']! as int) + 1 ||
              (fields['stage'] != stage && fields['stage'] != stage + 1) ||
              !fields.keys.every(
                const {'done', 'stage', 'updatedAt'}.contains,
              )) {
            deny('avancement du marqueur');
          }
        case DeleteOp():
          if (current == null) deny('suppression sans marqueur');
      }
    }
    for (final operation in operations) {
      final current = inner.read(operation.path);
      if (operation is SetOp &&
          current == null &&
          _studentData.any(operation.path.contains)) {
        final student = inner.read(
          'clubs/c1/students/${operation.fields['studentId']}',
        );
        if (student == null || student['erasing'] == true) {
          deny("donnée sur une fiche absente ou en cours d'effacement");
        }
      }
      if (operation is UpdateOp &&
          operation.path.contains('/students/') &&
          current?['erasing'] == true &&
          operation.fields['erasing'] != null &&
          operation.fields['erasing'] != true) {
        deny('erasing est irréversible');
      }
    }
  }

  @override
  Future<StoredDocument?> get(String path) => inner.get(path);

  @override
  Future<StoredDocument?> peek(String path) => inner.peek(path);

  @override
  Future<StoredDocument?> getFromServer(String path) =>
      inner.getFromServer(path);

  @override
  Future<List<StoredDocument>> list(String collection) =>
      inner.list(collection);

  @override
  Future<List<StoredDocument>> query(String collection, QueryFilter filter) =>
      inner.query(collection, filter);

  /// Sans cache dans ce double : la lecture au serveur est [query].
  @override
  Future<List<StoredDocument>> queryFromServer(
    String collection,
    QueryFilter filter,
  ) => query(collection, filter);

  /// Sans cache dans ce double : la lecture au serveur est [collectionGroup].
  @override
  Future<List<StoredDocument>> collectionGroupFromServer(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) => collectionGroup(collectionId, field: field, equalTo: equalTo);

  @override
  Future<List<StoredDocument>> collectionGroup(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) => inner.collectionGroup(collectionId, field: field, equalTo: equalTo);

  @override
  Stream<DocumentUpdate> watchDocument(String path) =>
      inner.watchDocument(path);

  @override
  Stream<CollectionUpdate> watchCollection(String collection) =>
      inner.watchCollection(collection);

  @override
  Stream<CollectionUpdate> watchQuery(String collection, QueryFilter filter) =>
      inner.watchQuery(collection, filter);

  @override
  Future<bool> createIfAbsent(String path, Fields fields) =>
      inner.createIfAbsent(path, fields);
}

/// Un club synchronisé `c1` sur un faux serveur, et les opérations
/// reprenables (effacement d'un élève, clôture de saison) par-dessus :
/// `FirestoreOperationStore`, `ClubStudentPurge`, `OperationRunner`, les
/// **vrais** dépôts Firestore.
///
/// Les données sont semées par des dépôts **sans règles** (le directeur du
/// monde de départ) ; les opérations passent par le faux serveur de règles
/// ([store]).
class OperationsWorld {
  OperationsWorld({this.uid = 'u-dir', Role role = Role.director})
    : server = InMemoryDocumentStore(),
      scope = SessionScope()..signIn(UserId(uid)) {
    store = OperationsRulesStore(server)..authUid = uid;
    scope.activate(clubId, role);
    club = ClubStore(store, scope);
    seedScope = SessionScope()
      ..signIn(const UserId('u-seed'))
      ..activate(clubId, Role.director);
    seeder = ClubStore(server, seedScope);
    server.serverNow = () => DateTime.utc(2026, 9);
    _repositories();
  }

  /// Ouvre un monde neuf et le rend courant.
  factory OperationsWorld.open({String uid = 'u-dir'}) =>
      current = OperationsWorld(uid: uid);

  /// Le monde du scénario en cours (les étapes y accèdent).
  static late OperationsWorld current;

  static const clubId = ClubId('c1');
  static const seasonId = SeasonId('season');
  static final day = DateTime(2026, 10, 12);

  final String uid;
  final InMemoryDocumentStore server;
  final SessionScope scope;
  late final SessionScope seedScope;
  late final OperationsRulesStore store;
  late final ClubStore club;
  late final ClubStore seeder;
  final FixedClock clock = FixedClock(DateTime.utc(2026, 10, 12, 10));

  late final InMemoryWriteLedger ledger = InMemoryWriteLedger(clock);
  late final FirestoreOperationStore operationStore = FirestoreOperationStore(
    club,
    scope,
  );

  /// La progression locale des séances guidées de CET appareil.
  final InMemoryRunProgressRepository runProgress =
      InMemoryRunProgressRepository();
  late final ClubStudentPurge purge = ClubStudentPurge(club, runProgress);
  late OperationRunner runner = OperationRunner(operationStore, ledger);

  late FirestoreStudentRepository students;
  late FirestoreGroupRepository groups;
  late FirestoreSeasonRepository seasons;
  late FirestoreSeasonArchiveRepository archives;
  late FirestoreSessionRecordRepository records;
  late FirestoreAttemptRepository attempts;
  late FirestoreSessionRepository plannedSessions;
  late FirestoreAssessmentRepository assessments;
  late FirestoreAcquisitionRepository acquisitions;
  late FirestoreAcknowledgementRepository acknowledgements;

  late FirestoreStudentRepository _seedStudents;
  late FirestoreGroupRepository _seedGroups;
  late FirestoreSeasonRepository _seedSeasons;
  late FirestoreSessionRecordRepository _seedRecords;
  late FirestoreAttemptRepository _seedAttempts;
  late FirestoreAcquisitionRepository _seedAcquisitions;
  late FirestoreAssessmentRepository _seedAssessments;
  late FirestoreAcknowledgementRepository _seedAcknowledgements;
  late FirestoreSessionRepository _seedPlanned;

  final Map<String, Group> _groupOf = {};

  /// Le groupe de chaque élève semé et les élèves semés, dans l'ordre.
  final Map<String, String> groupOfStudent = {};
  final List<String> studentNames = [];

  /// Le dernier élève dont l'effacement a été demandé.
  String? lastErased;
  int _counter = 0;

  /// Un identifiant de saisie qui ne nomme personne.
  String nextRecordId() => 'rec-${_counter++}';

  void _repositories() {
    students = FirestoreStudentRepository(club);
    groups = FirestoreGroupRepository(club);
    seasons = FirestoreSeasonRepository(club);
    archives = FirestoreSeasonArchiveRepository(club);
    records = FirestoreSessionRecordRepository(club);
    attempts = FirestoreAttemptRepository(club);
    plannedSessions = FirestoreSessionRepository(club);
    assessments = FirestoreAssessmentRepository(club);
    acquisitions = FirestoreAcquisitionRepository(club);
    acknowledgements = FirestoreAcknowledgementRepository(club, scope);
    _seedStudents = FirestoreStudentRepository(seeder);
    _seedGroups = FirestoreGroupRepository(seeder);
    _seedSeasons = FirestoreSeasonRepository(seeder);
    _seedRecords = FirestoreSessionRecordRepository(seeder);
    _seedAttempts = FirestoreAttemptRepository(seeder);
    _seedAcquisitions = FirestoreAcquisitionRepository(seeder);
    _seedAssessments = FirestoreAssessmentRepository(seeder);
    _seedAcknowledgements = FirestoreAcknowledgementRepository(
      seeder,
      seedScope,
    );
    _seedPlanned = FirestoreSessionRepository(seeder);
  }

  ClosureRepositories get closureRepositories => ClosureRepositories(
    seasons: seasons,
    groups: groups,
    students: students,
    sessionRecords: records,
    attempts: attempts,
    plannedSessions: plannedSessions,
    archives: archives,
  );

  /// L'effacement tel que l'écran l'appelle.
  ClubStudentErasure get erasure => ClubStudentErasure(runner, purge, scope);

  /// La clôture telle que l'assistant l'appelle.
  ClubSeasonClosing get closing => ClubSeasonClosing(
    runner,
    operationStore,
    purge,
    closureRepositories,
    scope,
  );

  /// Un second appareil du même compte : son propre exécuteur (mêmes dépôts,
  /// même serveur, même marqueur), avec son propre compte du jour.
  OperationRunner secondDevice() =>
      OperationRunner(operationStore, InMemoryWriteLedger(clock));

  // ───────────────────────── Semis ─────────────────────────

  static String idOf(String name) => 's-${name.toLowerCase()}';
  static StudentId studentId(String name) => StudentId(idOf(name));

  /// La saison, ouverte du 1er septembre 2026 au 30 juin 2027.
  Future<void> seedSeason() => _seedSeasons.save(
    Season(
      id: seasonId,
      label: '2026-2027',
      startDate: DateTime(2026, 9),
      endDate: DateTime(2027, 6, 30),
    ),
  );

  /// Un groupe d'enfants de la saison.
  Future<void> seedGroup(String name, {String? id}) async {
    final group = Group(
      id: GroupId(id ?? 'g-${name.toLowerCase()}'),
      seasonId: seasonId,
      name: name,
      audience: Audience.children,
    );
    _groupOf[name] = group;
    await _seedGroups.save(group);
  }

  /// Un élève inscrit dans [groupName] depuis le 1er septembre.
  Future<void> seedStudent(String name, {String groupName = 'Mardi'}) async {
    final id = studentId(name);
    await _seedStudents.create(
      Student.enroll(
        id: id,
        firstName: name,
        audience: Audience.children,
        since: DateTime(2026, 9),
      ),
    );
    final group = _groupOf[groupName]!.admit(
      studentId: id,
      studentAudience: Audience.children,
      from: DateTime(2026, 9),
    );
    _groupOf[groupName] = group;
    groupOfStudent[name] = groupName;
    studentNames.add(name);
    await _seedGroups.save(group);
  }

  /// Une séance donnée avec [present] présents.
  Future<SessionRecord> seedRecord(
    String id,
    String groupName,
    Iterable<String> present, {
    int dayOfMonth = 5,
  }) async {
    final group = _groupOf[groupName]!;
    final record = SessionRecord(
      id: SessionId(id),
      groupId: group.id,
      seasonId: seasonId,
      date: DateTime(2026, 10, dayOfMonth),
      audience: Audience.children,
      present: {for (final name in present) studentId(name)},
    );
    await _seedRecords.save(record);
    return record;
  }

  Future<void> seedAttempts(
    String name,
    String recordId,
    int count, {
    int offset = 0,
  }) async {
    for (var i = 0; i < count; i++) {
      await _seedAttempts.add(
        ExerciseAttempt(
          id: AttemptId('a-${name.toLowerCase()}-${offset + i}'),
          studentId: studentId(name),
          sessionId: SessionId(recordId),
          exercise: ExerciseRef(blockId: 'puissance', number: 1 + i % 3),
          date: DateTime(2026, 10, 5),
          potted: 3 + i % 2,
          total: 5,
        ),
      );
    }
  }

  Future<void> seedAssessment(String name) => _seedAssessments.add(
    MaturityAssessment(
      id: AssessmentId('as-${name.toLowerCase()}-${_counter++}'),
      studentId: studentId(name),
      date: DateTime(2026, 10, 5),
      concentration: 3,
      endurance: 2,
      frustration: 4,
    ),
  );

  Future<void> seedAcquisition(String name) => _seedAcquisitions.add(
    BlockAcquisition(
      id: AcquisitionId('q-${name.toLowerCase()}-${_counter++}'),
      studentId: studentId(name),
      blockId: 'puissance',
      date: DateTime(2026, 9, 15),
      source: AcquisitionSource.placement,
    ),
  );

  Future<void> seedAcknowledgement(String name) => _seedAcknowledgements.add(
    AlertAcknowledgement(
      id: AcknowledgementId('k-${name.toLowerCase()}-${_counter++}'),
      studentId: studentId(name),
      exercise: ExerciseRef(blockId: 'puissance', number: 1),
      lastAttemptId: AttemptId('a-${name.toLowerCase()}-0'),
      date: DateTime(2026, 10, 5),
    ),
  );

  /// Une séance planifiée du groupe (pour la clôture).
  Future<void> seedPlanned(String id, String groupName, DateTime date) =>
      _seedPlanned.add(
        Session(
          id: id,
          title: 'Séance $id',
          date: date,
          audience: Audience.children,
          groupId: _groupOf[groupName]!.id,
        ),
      );

  /// Un appareil en retard ajoute [id] aux présents de la saisie [recordId],
  /// sans règle (aucune règle ne parcourt une liste).
  void addPresence(String recordId, StudentId id) {
    final path = 'clubs/c1/records/$recordId';
    final record = server.documents[path]!;
    server.seed(path, {
      ...record,
      'presentStudentIds': [...record['presentStudentIds']! as List, id.value],
    });
  }

  /// L'étape du marqueur d'opération de ce compte, s'il existe.
  int? stageOfMarker() {
    for (final entry in server.documents.entries) {
      if (entry.key.contains('/operations/') && entry.key.endsWith('_$uid')) {
        return entry.value['stage'] as int?;
      }
    }
    return null;
  }

  /// L'identifiant d'une saisie où [id] est (ou était) présent.
  String recordPresenting(StudentId id) {
    for (final entry in server.documents.entries) {
      if (!entry.key.contains('/records/')) continue;
      final present = entry.value['presentStudentIds'];
      if (present is List && present.contains(id.value)) {
        return entry.key.split('/').last;
      }
    }
    return fail('aucune saisie ne compte ${id.value}');
  }

  /// Le compte d'un parent lié à la fiche de [name] (et à celles de [also]).
  void seedGuardian(
    String name, {
    String uid = 'u-parent',
    List<String> also = const [],
  }) {
    server.seed('clubs/c1/members/$uid', {
      'uid': uid,
      'role': 'guardian',
      'displayName': uid,
      'groupIds': <String>[],
      'studentIds': [idOf(name), for (final other in also) idOf(other)],
    });
  }

  /// Le compte de rôle élève lié à la fiche de [name].
  void seedStudentAccount(String name, {String uid = 'u-eleve'}) {
    server.seed('clubs/c1/members/$uid', {
      'uid': uid,
      'role': 'student',
      'displayName': name,
      'groupIds': <String>[],
      'studentIds': [idOf(name)],
    });
  }

  /// Le directeur du club.
  void seedDirector() {
    server.seed('clubs/c1/members/$uid', {
      'uid': uid,
      'role': 'director',
      'displayName': uid,
      'groupIds': <String>[],
      'studentIds': <String>[],
    });
  }

  // ───────────────────────── Lectures ─────────────────────────

  Fields? doc(String path) => server.read(path);

  /// Tous les documents du club dont le contenu se rapporte à [name] :
  /// chemin ou valeur de champ (identifiant d'élève), liste comprise.
  List<String> documentsAbout(String name) => documentsAboutId(idOf(name));

  /// Idem, pour l'identifiant [id] de la fiche.
  List<String> documentsAboutId(String id) {
    bool mentions(Object? value) => switch (value) {
      String() => value == id || value.contains(id),
      List<Object?>() => value.any(mentions),
      Map<Object?, Object?>() => value.values.any(mentions),
      _ => false,
    };
    return [
      for (final entry in server.documents.entries)
        if (entry.key.contains(id) || entry.value.values.any(mentions))
          entry.key,
    ];
  }

  /// Les documents du serveur, sans les champs qui dépendent de l'heure de
  /// l'exécution.
  Map<String, Map<String, Object?>> clubDocuments({bool markers = false}) => {
    for (final entry in server.documents.entries)
      if (markers || !entry.key.contains('/operations/'))
        entry.key: {
          for (final field in entry.value.entries)
            if (field.key != 'recordedAt') field.key: field.value,
        },
  };

  /// Les marqueurs d'opération encore présents.
  Map<String, Fields> markers() => {
    for (final entry in server.documents.entries)
      if (entry.key.contains('/operations/')) entry.key: entry.value,
  };

  Role get role => scope.role!;

  /// Les dépôts dans lesquels semer un club (sans règles).
  ClubSeedTarget get seedTarget => ClubSeedTarget(
    seasons: _seedSeasons,
    groups: _seedGroups,
    students: _seedStudents,
    records: _seedRecords,
    attempts: _seedAttempts,
    assessments: _seedAssessments,
    acquisitions: _seedAcquisitions,
    acknowledgements: _seedAcknowledgements,
    planned: _seedPlanned,
  );

  /// L'état du club tel que les dépôts du compte courant le lisent.
  Future<Map<String, Object?>> state() => canonicalState(
    seasons: seasons,
    groups: groups,
    students: students,
    records: records,
    attempts: attempts,
    assessments: assessments,
    acquisitions: acquisitions,
    acknowledgements: acknowledgements,
    planned: plannedSessions,
    archives: archives,
  );

  /// Un **autre compte** du même club (un administrateur, par exemple) : son
  /// propre faux serveur de règles, sa session, son marqueur ; le même stock de
  /// documents.
  OperationsActor actor({required String uid, required Role role}) =>
      OperationsActor(this, uid: uid, role: role);

  // ───────────────────────── État d'un scénario ─────────────────────────

  /// Le compte rendu du dernier effacement ([result] pour un autre) ; échoue
  /// si l'effacement a été refusé.
  ErasureOutcome erasureOutcome([Result<ErasureOutcome>? result]) =>
      switch (result ?? erasureResult) {
        Ok(:final value) => value,
        final other => fail('effacement refusé ou absent : $other'),
      };

  /// Le compte rendu de la dernière clôture ([result] pour une autre) ; échoue
  /// si la clôture a été refusée.
  ClosureOutcome closureOutcome([Result<ClosureOutcome>? result]) =>
      switch (result ?? closureResult) {
        Ok(:final value) => value,
        final other => fail('clôture refusée ou absente : $other'),
      };

  /// La forme du club semé par `seedSpec`, qui a été semé, et les élèves à
  /// effacer à la clôture.
  ClubSpec? spec;
  SeededClub? seeded;
  Set<StudentId> toErase = const {};

  /// L'administrateur qui a commencé d'effacer [adminErased] (une clôture
  /// absorbe l'effacement en cours d'un autre auteur).
  OperationsActor? admin;
  StudentId? adminErased;
  Result<ErasureOutcome>? adminErasure;
  Result<ClosureOutcome>? closureResult;
  bool prepareNext = true;
  bool dropPlanned = true;

  /// Les résultats de plusieurs clôtures menées de front.
  List<Result<ClosureOutcome>> closureResults = const [];

  /// Sème le club décrit par [clubSpec] (rejoué sur le monde de référence).
  Future<void> seedSpec(ClubSpec clubSpec) async {
    await seeding((w) async {
      w.spec = clubSpec;
      w.seeded = await seedClub(clubSpec, w.seedTarget);
    });
  }

  /// Clôt la saison avec les choix du monde ([toErase], [prepareNext],
  /// [dropPlanned]) par [closing] et garde le résultat.
  Future<Result<ClosureOutcome>> close({ClubSeasonClosing? by}) async {
    batchesMark = store.appliedBatches;
    return closureResult = await (by ?? closing).close(
      seasonId: seasonId,
      closedOn: day,
      erase: toErase,
      prepareNext: prepareNext,
      dropPlanned: dropPlanned,
    );
  }

  /// Une clôture commencée par ce compte reste-t-elle à reprendre ?
  Future<bool> hasPendingClosure({ClubSeasonClosing? by}) async =>
      switch (await (by ?? closing).pending()) {
        Ok(:final value) => value != null,
        final other => fail('lecture du marqueur refusée : $other'),
      };

  /// Reprend la clôture trouvée par [by] (par défaut, celle de ce compte).
  Future<Result<ClosureOutcome>> resumeFound({ClubSeasonClosing? by}) async {
    final closing = by ?? this.closing;
    final pending = await closing.pending();
    final terms = switch (pending) {
      Ok(:final value) => value,
      Err(:final failure) => fail('reprise impossible : $failure'),
    };
    if (terms == null) fail('aucune clôture à reprendre');
    return closureResult = await closing.resume(terms);
  }

  /// Le même club, clos **en un seul lot** par `CloseSeason` sur des dépôts en
  /// mémoire : la référence de « même résultat ».
  Future<Map<String, Object?>> oneShotReference({
    required bool prepareNext,
    required bool dropPlanned,
  }) async {
    final memory = DomainWorld();
    await seedClub(
      spec!,
      ClubSeedTarget(
        seasons: memory.seasons,
        groups: memory.groups,
        students: memory.students,
        records: memory.sessions,
        attempts: memory.attempts,
        assessments: memory.assessments,
        acquisitions: memory.acquisitions,
        acknowledgements: memory.acknowledgements,
        planned: memory.plannedSessions,
      ),
    );
    final close = CloseSeason(
      memory.seasons,
      memory.groups,
      memory.students,
      memory.sessions,
      memory.attempts,
      memory.plannedSessions,
      memory.seasonArchives,
      memory.studentEraser(),
      memory.ids,
      InMemoryUnitOfWork(),
    );
    final result = await close(
      seasonId: seasonId,
      closedOn: day,
      erase: toErase,
      prepareNext: prepareNext,
      dropPlanned: dropPlanned,
    );
    expect(result, isA<Ok<ClosureResult>>(), reason: '$result');
    return await canonicalState(
      seasons: memory.seasons,
      groups: memory.groups,
      students: memory.students,
      records: memory.sessions,
      attempts: memory.attempts,
      assessments: memory.assessments,
      acquisitions: memory.acquisitions,
      acknowledgements: memory.acknowledgements,
      planned: memory.plannedSessions,
      archives: memory.seasonArchives,
    );
  }

  /// Le dernier effacement demandé et le dernier refus du serveur.
  Result<ErasureOutcome>? erasureResult;
  bool lastWriteRefused = false;

  /// Lots appliqués au moment où un scénario pose un repère.
  int batchesMark = 0;

  /// La première saisie créée pour chaque élève.
  final Map<String, String> firstRecord = {};

  /// Ce qui a été semé pour chaque élève (comparaisons).
  final Map<String, SeededCounts> seededCounts = {};

  /// Les semis dans l'ordre : rejoués sur un monde neuf, ils donnent le monde
  /// de référence (opération menée sans coupure).
  final List<Future<void> Function(OperationsWorld world)> recipe = [];

  /// Exécute [step] sur ce monde et le retient pour le monde de référence.
  Future<void> seeding(
    Future<void> Function(OperationsWorld world) step,
  ) async {
    recipe.add(step);
    await step(this);
  }

  /// Un monde neuf, semé comme celui-ci.
  Future<OperationsWorld> freshReference() async {
    final reference = OperationsWorld(uid: uid);
    for (final step in recipe) {
      await step(reference);
    }
    return reference;
  }
}

/// Un autre compte du club, sur le même stock de documents.
class OperationsActor {
  OperationsActor(
    OperationsWorld world, {
    required this.uid,
    required Role role,
  }) : scope = SessionScope()..signIn(UserId(uid)) {
    store = OperationsRulesStore(world.server)..authUid = uid;
    scope.activate(OperationsWorld.clubId, role);
    club = ClubStore(store, scope);
    operationStore = FirestoreOperationStore(club, scope);
    purge = ClubStudentPurge(club, InMemoryRunProgressRepository());
    runner = OperationRunner(operationStore, InMemoryWriteLedger(world.clock));
    closing = ClubSeasonClosing(
      runner,
      operationStore,
      purge,
      ClosureRepositories(
        seasons: FirestoreSeasonRepository(club),
        groups: FirestoreGroupRepository(club),
        students: FirestoreStudentRepository(club),
        sessionRecords: FirestoreSessionRecordRepository(club),
        attempts: FirestoreAttemptRepository(club),
        plannedSessions: FirestoreSessionRepository(club),
        archives: FirestoreSeasonArchiveRepository(club),
      ),
      scope,
    );
    erasure = ClubStudentErasure(runner, purge, scope);
  }

  final String uid;
  final SessionScope scope;
  late final OperationsRulesStore store;
  late final ClubStore club;
  late final FirestoreOperationStore operationStore;
  late final ClubStudentPurge purge;
  late final OperationRunner runner;
  late final ClubSeasonClosing closing;
  late final ClubStudentErasure erasure;
}

/// Ce qui a été semé pour un élève.
final class SeededCounts {
  const SeededCounts({
    required this.attempts,
    required this.assessments,
    required this.acknowledgements,
    required this.acquisitions,
    required this.presences,
  });

  final int attempts;
  final int assessments;
  final int acknowledgements;
  final int acquisitions;
  final int presences;
}
