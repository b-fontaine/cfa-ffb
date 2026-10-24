import 'dart:io';

import 'package:billard_cfa/app/firestore_club_import_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_catalog/data/catalogue_yaml_parser.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_rules.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/prepare_club_import.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixed_clock.dart';
import 'in_memory_import_daily_ledger.dart';
import 'realistic_backup.dart';
import 'session_sheet_fixtures.dart';

/// Le catalogue réel de l'application, lu depuis l'asset sur disque.
class DiskCatalogue implements CatalogueRepository {
  @override
  Future<ExerciseCatalogue> load() async => parseCatalogue(
    File('assets/catalogue/catalogue-entrainement.yaml').readAsStringSync(),
  );
}

/// Un **faux serveur** devant le stock en mémoire, qui applique ce que les
/// règles Firestore imposent à l'import (`scripts/rules_test/import.test.mjs`
/// les joue pour de vrai) :
///
/// - **le marqueur** `clubs/{c}/imports/{fileId}_{uid}` (propre à son
///   auteur) : création avec
///   `done == 1`, puis avancement d'**exactement un** lot par lot ; tout
///   autre écrit refusé ;
/// - **aucun écrasement** : une écriture simple sur un document qui existe est
///   refusée (plus strict que les règles : l'import ne modifie jamais ce qui
///   existe) ; seule la fusion de `groupIds` d'une fiche passe ;
/// - **tout lot d'import porte le marqueur**, et au plus 400 écritures ;
/// - `createdAt` de chaque lot est **la date du serveur à ce lot**
///   (`request.time`), croissante d'un lot à l'autre.
///
/// Il simule aussi les coupures : [failAfterBatches] (le réseau tombe avant le
/// lot suivant) et [dropAckAt] (le lot est appliqué mais l'accusé est perdu).
class RulesLiteStore implements DocumentStore {
  RulesLiteStore(this.inner);

  final InMemoryDocumentStore inner;

  /// Lots appliqués et écritures acceptées (assertions).
  int appliedBatches = 0;
  int appliedWrites = 0;

  /// Après ce nombre de lots appliqués, le lot suivant échoue (`unavailable`)
  /// **sans** être appliqué.
  int? failAfterBatches;

  /// Le lot d'indice [dropAckAt] (à partir de 0) est appliqué, puis le réseau
  /// tombe avant l'accusé : l'appelant reçoit `unavailable`.
  int? dropAckAt;

  /// Attend avant d'appliquer chaque lot (un serveur lent : les tests de
  /// l'écran y demandent l'arrêt de l'import pendant un lot).
  Future<void> Function()? beforeCommit;

  /// Le compte connecté (`request.auth.uid`) : son marqueur seul est permis.
  String? authUid;

  /// La date du serveur du premier lot ; chaque lot ajoute une seconde.
  DateTime serverStart = DateTime.utc(2026, 10, 12, 9);

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
    appliedBatches++;
    appliedWrites += operations.length;
    if (dropAckAt == appliedBatches - 1) {
      dropAckAt = null;
      throw const StoreFailure(StoreFailureCode.unavailable, 'accusé perdu');
    }
  }

  void _validate(List<WriteOp> operations) {
    Never deny(String why) =>
        throw StoreFailure(StoreFailureCode.permissionDenied, why);
    if (operations.length > 400) deny('plus de 400 écritures');
    // Les règles lisent la fiche de chaque passage, bloc acquis, bilan ou
    // acquittement : au plus 20 documents distincts par lot, dont `member` et
    // `admins/{uid}` (mesuré à l'émulateur : 18 fiches distinctes au plus).
    final students = {
      for (final op in operations)
        if (op is SetOp &&
            const [
              '/attempts/',
              '/acquisitions/',
              '/assessments/',
              '/acknowledgements/',
            ].any(op.path.contains))
          op.fields['studentId'],
    };
    if (students.length > 18) deny('plus de 18 fiches distinctes par lot');
    final markers = operations.where((o) => o.path.contains('/imports/'));
    if (markers.length != 1) deny('un lot porte exactement un marqueur');
    // Le marqueur est celui de son auteur : `{empreinte}_{uid}`, et le compte
    // connecté est cet uid (règle `markerId == fileId + '_' + auth.uid`).
    final marker = markers.single;
    final uid = authUid;
    if (uid != null && !marker.path.endsWith('_$uid')) {
      deny("marqueur d'un autre auteur");
    }
    if (marker case SetOp(:final fields)
        when !marker.path.endsWith(
          '/${fields['fileId']}_${fields['createdBy']}',
        )) {
      deny('identifiant du marqueur');
    }
    for (final operation in operations) {
      final current = inner.read(operation.path);
      if (operation.path.contains('/imports/')) {
        switch (operation) {
          case SetOp(:final fields):
            if (current != null || fields['done'] != 1) deny('marqueur');
          case UpdateOp(:final fields):
            if (current == null ||
                current['state'] != 'running' ||
                fields['done'] != (current['done']! as int) + 1) {
              deny('avancement du marqueur');
            }
          case DeleteOp():
            deny('suppression du marqueur');
        }
        continue;
      }
      switch (operation) {
        case SetOp(:final merge):
          if (current != null && !merge) deny('document existant');
        case UpdateOp():
          deny('mise à jour hors marqueur');
        case DeleteOp():
          deny('suppression');
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

/// Un club synchronisé `c1` sur un faux serveur, et le moteur d'import
/// par-dessus (`PrepareClubImport`, `ClubImportRunner`,
/// `FirestoreClubImportStore`).
class ImportWorld {
  ImportWorld({this.limits = const ImportLimits()})
    : server = InMemoryDocumentStore(),
      scope = SessionScope()..signIn(const UserId('u-import')) {
    store = RulesLiteStore(server)..authUid = 'u-import';
    club = ClubStore(store, scope);
    importStore = FirestoreClubImportStore(club, scope);
    catalogue = DiskCatalogue();
  }

  /// Ouvre un monde neuf et le rend courant.
  factory ImportWorld.open([ImportLimits limits = const ImportLimits()]) =>
      current = ImportWorld(limits: limits);

  /// Le monde du scénario en cours (les étapes y accèdent).
  static late ImportWorld current;

  static const clubId = ClubId('c1');
  static final now = DateTime.utc(2026, 10, 12, 10);

  ImportLimits limits;
  final InMemoryDocumentStore server;
  final SessionScope scope;
  late final RulesLiteStore store;
  late final ClubStore club;
  late final FirestoreClubImportStore importStore;
  late final CatalogueRepository catalogue;

  RealisticBackup? backup;
  String? content;
  ImportDecisions decisions = ImportDecisions.none;
  Role role = Role.director;

  /// Les groupes de l'enseignant qui importe.
  final Set<String> teacherGroups = {};
  ClubImportPlan? plan;
  ImportRunResult? run;
  int batchesBeforeSecondPrepare = 0;

  /// Active le club avec [role] et, pour un enseignant, ses [groups].
  void act(Role newRole, {List<String> groups = const []}) {
    role = newRole;
    scope.activate(
      clubId,
      newRole,
      groupIds: [for (final g in groups) GroupId(g)],
    );
  }

  PrepareClubImport get prepareUseCase => prepareUseCaseWith(importStore);

  /// Le même cas d'usage sur un autre club (autre stock de documents).
  PrepareClubImport prepareUseCaseWith(ClubImportStore store) =>
      PrepareClubImport(
        BackupCodec(),
        BackupRules(
          catalogue,
          FixtureSessionSheetRepository(catalogueFixture()),
          RulesConfig(),
          FixedClock(now),
        ),
        store,
        scope,
        clock,
      );

  /// L'horloge du monde (le jour du plafond d'écritures) et le compte du jour,
  /// gardé d'une exécution à l'autre comme sur l'appareil.
  final FixedClock clock = FixedClock(now);
  late final InMemoryImportDailyLedger dailyLedger = InMemoryImportDailyLedger(
    clock,
  );

  ClubImportRunner get runner => ClubImportRunner(importStore, dailyLedger);

  /// Prépare l'import du fichier courant avec les décisions courantes.
  Future<ClubImportPlan> prepare({Set<StudentId>? newer}) async {
    final result = await prepareUseCase(
      content!,
      decisions: decisions,
      limits: limits,
      newerFileStudents: newer,
    );
    return plan = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('préparation refusée : $failure'),
    };
  }

  /// Écrit le plan courant.
  Future<ImportRunResult> runPlan({int? budget}) async {
    final result = await runner(plan!, role: role, budget: budget);
    return run = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('exécution refusée : $failure'),
    };
  }

  /// Toutes les décisions « créer » pour les groupes du fichier.
  ImportDecisions createAll() => decisions.copyWith(
    groups: {
      for (final g in backup!.snapshot.groups) g.id: const CreateGroup(),
    },
  );

  /// Les documents du serveur, sans les champs qui dépendent de l'heure de
  /// l'exécution (le marqueur est comparé à part).
  Map<String, Map<String, Object?>> clubDocuments({bool markers = false}) => {
    for (final entry in server.documents.entries)
      if (markers || !entry.key.contains('/imports/'))
        entry.key: {
          for (final field in entry.value.entries)
            if (field.key != 'recordedAt') field.key: field.value,
        },
  };

  /// Les passages relus par le dépôt, dans l'ordre que l'application leur
  /// donne.
  Future<List<String>> attemptIds() async => [
    for (final a in await FirestoreAttemptRepository(club).all()) a.id.value,
  ];

  Fields? marker() {
    final paths = [
      for (final path in server.documents.keys)
        if (path.contains('/imports/')) path,
    ];
    return paths.isEmpty ? null : server.read(paths.single);
  }

  /// Un import complet de [content] dans un monde neuf, pour comparer.
  Future<Map<String, Map<String, Object?>>> referenceImport() async {
    final world = ImportWorld(limits: limits)
      ..backup = backup
      ..content = content
      ..decisions = decisions
      ..act(Role.director);
    seedInto(world);
    await world.prepare();
    expect(world.plan!.isRunnable, isTrue, reason: '${world.plan!.status}');
    final result = await world.runPlan(budget: 1 << 30);
    expect(result.status, ImportRunStatus.completed);
    return world.clubDocuments();
  }

  /// Les documents semés avant l'import (copiés dans le monde de référence).
  final Map<String, Fields> seeded = {};

  void seed(String path, Fields fields) {
    seeded[path] = fields;
    server.seed(path, fields);
  }

  void seedInto(ImportWorld other) =>
      seeded.forEach((path, fields) => other.server.seed(path, fields));

  /// Sème un groupe du club (et sa saison) confié à [teacher].
  void seedClubGroup({
    required String id,
    required String name,
    required String audience,
    required String teacher,
  }) {
    seed('clubs/c1/seasons/season-club', {
      'label': '2026-2027',
      'startDate': '2026-09-01T00:00:00.000',
      'endDate': '2027-06-30T00:00:00.000',
      'closedOn': null,
    });
    seed('clubs/c1/groups/$id', {
      'seasonId': 'season-club',
      'name': name,
      'audience': audience,
      'teacherUids': [teacher],
    });
  }
}
