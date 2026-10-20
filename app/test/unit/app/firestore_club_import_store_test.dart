import 'dart:async';

import 'package:billard_cfa/app/firestore_club_import_store.dart';
import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/firestore_assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/import_world.dart';
import '../../support/realistic_backup.dart';

/// L'adaptateur Firestore de l'import : ce qu'il écrit (champs exacts), ce
/// qu'il refuse d'écraser, ce qu'il lit selon le rôle, et le tout rejoué sur
/// le vrai `FirestoreDocumentStore` (faux Firestore en mémoire) puis relu par
/// les vrais dépôts : la relecture complète est comparée au fichier.
void main() {
  final backup = RealisticBackup(history: true);

  Future<ImportWorld> imported({
    RealisticBackup? file,
    void Function(ImportWorld world)? seed,
  }) async {
    final world = ImportWorld.open()
      ..act(Role.director)
      ..backup = file ?? backup;
    world.content = world.backup!.content;
    seed?.call(world);
    world.decisions = world.createAll();
    final plan = await world.prepare();
    expect(plan.status, ImportStatus.ready, reason: '${plan.report.problems}');
    final run = await world.runPlan();
    expect(run.status, ImportRunStatus.completed);
    return world;
  }

  group('the documents written', () {
    late ImportWorld world;
    late Map<String, Map<String, Object?>> documents;
    final serverTime = DateTime.utc(2026, 10, 12, 9);

    setUpAll(() async {
      world = await imported();
      documents = world.server.documents;
    });

    test(
      'a student: first name, audience, history, current groups, creation date',
      () {
        final student = documents['clubs/c1/students/s-g1-1']!;
        expect(student['firstName'], 'Élève11');
        expect(student['audience'], 'children');
        expect(student['groupIds'], ['g1']);
        expect(student['createdAt'], isA<DateTime>());
        expect((student['audienceHistory']! as List).single, {
          'audience': 'children',
          'effectiveFrom': '2026-09-01T00:00:00.000',
        });
        expect(student.keys.toSet(), {
          'firstName',
          'audience',
          'audienceHistory',
          'groupIds',
          'createdAt',
          'importedAt',
        });
      },
    );

    test('a membership, with the id of the application', () {
      final membership =
          documents['clubs/c1/memberships/g1_s-g1-1_2026-09-01T00:00:00.000']!;
      expect(membership, {
        'groupId': 'g1',
        'seasonId': 'season',
        'studentId': 's-g1-1',
        'from': '2026-09-01T00:00:00.000',
        'to': null,
        'importedAt': isA<DateTime>(),
      });
    });

    test(
      'a group is created without teachers, a season with its closing date',
      () {
        expect(documents['clubs/c1/groups/g1'], {
          'seasonId': 'season',
          'name': 'Groupe 1',
          'audience': 'children',
          'teacherUids': <String>[],
          'importedAt': isA<DateTime>(),
        });
        expect(
          documents['clubs/c1/seasons/season-old']!['closedOn'],
          isNotNull,
        );
        expect(documents['clubs/c1/seasons/season']!['closedOn'], isNull);
      },
    );

    test('an attempt carries its owner, the server date and a recordedAt', () {
      final attempt = documents['clubs/c1/attempts/a-g1-1-1-0']!;
      expect(attempt['groupId'], 'g1');
      expect(attempt['seasonId'], 'season');
      expect(attempt['studentId'], 's-g1-1');
      expect(attempt['sessionId'], 'g1_20260908_demi-bille-1');
      expect(attempt['blockId'], 'puissance');
      expect(attempt['exerciseNumber'], 1);
      expect(attempt['potted'], 3);
      expect(attempt['total'], 5);
      expect(attempt['recordedAt'], isA<DateTime>());
      expect(attempt.keys.toSet(), containsAll(['createdAt', 'recordedAt']));
    });

    test(
      'createdAt is the server date of the lot, growing from lot to lot',
      () {
        final byLot = <DateTime>{
          for (final entry in documents.entries)
            if (entry.key.contains('/attempts/'))
              entry.value['createdAt']! as DateTime,
        };
        expect(byLot, isNotEmpty);
        expect(byLot.every((d) => !d.isBefore(serverTime)), isTrue);
      },
    );

    test('an acknowledgement is signed by the account that imports', () {
      final ack = documents['clubs/c1/acknowledgements/k-g1']!;
      expect(ack['createdBy'], 'u-import');
      expect(ack['groupId'], 'g1');
      expect(ack['studentId'], 's-g1-1');
    });

    test('a planned session, a record, archives', () {
      expect(documents['clubs/c1/sessions/p-g1']!['groupId'], 'g1');
      expect(documents['clubs/c1/sessions/p-g1']!['seasonId'], 'season');
      final record = documents['clubs/c1/records/g1_20260908_demi-bille-1']!;
      expect(record['presentStudentIds'], ['s-g1-1', 's-g1-2', 's-g1-3']);
      expect(record['sheetId'], 'demi-bille-1');
      expect(record['tags'], ['gameAppreciated']);
      expect(
        documents.keys.where((p) => p.contains('/archives/')),
        unorderedEquals([
          'clubs/c1/archives/season-old_children',
          'clubs/c1/archives/season-old_children_puissance_1',
        ]),
      );
    });

    test('the marker holds no personal data', () {
      final marker = world.marker()!;
      expect(marker['fileId'], world.plan!.fingerprint);
      expect(marker['planId'], world.plan!.planId);
      expect(marker['writes'], world.plan!.totalWrites);
      expect(marker['role'], 'director');
      expect('$marker', isNot(contains('Élève')));
      // Seul l'identifiant (pseudonyme) de l'auteur : la règle d'avancement.
      expect(marker['createdBy'], 'u-import');
    });

    test(
      'every created document is stamped, attempts and records excepted',
      () {
        // Passages et saisies : déjà protégés par `createdAt` (règles) ; les
        // autres documents portent `importedAt`, qu'une mise à jour ne pose
        // ni ne change.
        final stamped = {
          for (final entry in documents.entries)
            if (!entry.key.contains('/imports/'))
              entry.key: entry.value.containsKey('importedAt'),
        };
        for (final entry in stamped.entries) {
          final exempt =
              entry.key.contains('/attempts/') ||
              entry.key.contains('/records/');
          expect(entry.value, !exempt, reason: entry.key);
        }
      },
    );
  });

  group('never overwriting', () {
    test('a document that exists is left as it is', () async {
      final world = await imported(
        seed: (world) => world
          ..seed('clubs/c1/students/s-g1-1', {
            'firstName': 'Déjà là',
            'groupIds': <String>[],
          })
          ..seed('clubs/c1/attempts/a-g1-1-1-0', {
            'groupId': 'g1',
            'studentId': 's-g1-1',
            'potted': 0,
          }),
      );
      final documents = world.server.documents;
      expect(documents['clubs/c1/students/s-g1-1']!['firstName'], 'Déjà là');
      expect(documents['clubs/c1/attempts/a-g1-1-1-0']!['potted'], 0);
      // La fiche reçoit seulement les groupes qui lui manquent.
      expect(documents['clubs/c1/students/s-g1-1']!['groupIds'], ['g1']);
      // Le reste du fichier est là.
      expect(
        documents.keys.where((p) => p.contains('/attempts/')),
        hasLength(backup.attemptCount),
      );
    });

    test(
      'a student that already has its groups is not written at all',
      () async {
        final world = await imported(
          seed: (world) => world.seed('clubs/c1/students/s-g1-1', {
            'firstName': 'Déjà là',
            'groupIds': ['g1'],
          }),
        );
        expect(world.server.documents['clubs/c1/students/s-g1-1'], {
          'firstName': 'Déjà là',
          'groupIds': ['g1'],
        });
      },
    );

    test('a club holding a first import converges with the next one', () async {
      // Un import précédent d'un autre fichier a déjà écrit des passages.
      final first = RealisticBackup(sessionsPerGroup: 2);
      final world = await imported(file: first);
      final before = world.server.documents.length;
      final next = ImportWorld.open()
        ..act(Role.director)
        ..backup = backup
        ..content = backup.content;
      world.server.documents.forEach(next.server.seed);
      next.decisions = next.createAll();
      final plan = await next.prepare();
      expect(
        plan.status,
        ImportStatus.ready,
        reason: '${plan.report.problems}',
      );
      final run = await next.runPlan();
      expect(run.status, ImportRunStatus.completed);
      expect(next.server.documents.length, greaterThan(before));
      // Les passages de la première sauvegarde sont restés tels quels.
      for (final entry in world.server.documents.entries) {
        if (entry.key.contains('/attempts/')) {
          expect(next.server.documents[entry.key], entry.value);
        }
      }
    });
  });

  group('reading the club', () {
    test(
      'a director lists the collections; nothing personal comes back',
      () async {
        final world = await imported();
        final inventory = await world.importStore.inventory('f' * 64);
        expect(inventory.groups.keys.map((g) => g.value), ['g1', 'g2']);
        expect(inventory.students, hasLength(6));
        expect(inventory.students[backup.studentId(1, 1)], {backup.groupId(1)});
        expect(
          inventory.existing[ImportCategory.attempts],
          hasLength(backup.attemptCount),
        );
        expect(inventory.seasons.keys.map((s) => s.value), [
          'season',
          'season-old',
        ]);
        expect(inventory.seasons[RealisticBackup.oldSeason]!.isClosed, isTrue);
        expect(inventory.marker, isNull);
        expect(inventory.erasingStudents, isEmpty);
      },
    );

    test('the marker of this file is read, another file has none', () async {
      final world = await imported();
      final fingerprint = world.plan!.fingerprint;
      expect(
        (await world.importStore.inventory(fingerprint)).marker!.done,
        world.plan!.lots.length,
      );
      expect(
        (await world.importStore.readMarker(fingerprint))!.state,
        ImportState.done,
      );
      expect(await world.importStore.readMarker('0' * 64), isNull);
    });

    test("the marker is its author's own: another account's marker for the "
        'same file changes nothing', () async {
      final world = ImportWorld.open()
        ..act(Role.director)
        ..backup = backup
        ..content = backup.content;
      world.decisions = world.createAll();
      final fingerprint = (await world.prepare()).fingerprint;
      // Un enseignant pose un marqueur « terminé » au nom du fichier.
      world.seed('clubs/c1/imports/${fingerprint}_u-teacher', {
        'fileId': fingerprint,
        'planId': 'd' * 64,
        'lots': 1,
        'done': 1,
        'writes': 0,
        'restored': 0,
        'role': 'teacher',
        'createdBy': 'u-teacher',
        'state': 'done',
      });
      expect(await world.importStore.readMarker(fingerprint), isNull);
      expect((await world.importStore.inventory(fingerprint)).marker, isNull);
      final plan = await world.prepare();
      expect(plan.status, ImportStatus.ready);
      final run = await world.runPlan();
      expect(run.status, ImportRunStatus.completed);
      // Le marqueur du directeur est sous SON identifiant.
      expect(
        world.server.documents.keys.where((p) => p.contains('/imports/')),
        containsAll([
          'clubs/c1/imports/${fingerprint}_u-import',
          'clubs/c1/imports/${fingerprint}_u-teacher',
        ]),
      );
      expect(
        world.server.read(
          'clubs/c1/imports/${fingerprint}_u-import',
        )!['createdBy'],
        'u-import',
      );
    });

    test(
      'without a signed-in account there is no marker to write or read',
      () async {
        final scope = SessionScope()
          ..activate(ImportWorld.clubId, Role.director);
        final server = InMemoryDocumentStore();
        final store = FirestoreClubImportStore(
          ClubStore(RulesLiteStore(server), scope),
          scope,
        );
        await expectLater(
          store.readMarker('a' * 64),
          throwsA(
            isA<ServiceFailure>().having(
              (f) => f.code,
              'code',
              ServiceFailureCode.denied,
            ),
          ),
        );
      },
    );

    group('the marker is read from the server, never from the cache', () {
      const fingerprint =
          'e0000000000000000000000000000000'
          '00000000000000000000000000000000';
      const path = 'clubs/c1/imports/${fingerprint}_u-import';
      Map<String, Object?> marker(int done) => {
        'fileId': fingerprint,
        'planId': 'p' * 64,
        'lots': 5,
        'done': done,
        'writes': 100,
        'restored': 0,
        'role': 'director',
        'createdBy': 'u-import',
      };

      FirestoreClubImportStore storeOver(_StaleCacheStore documents) {
        final scope = SessionScope()
          ..signIn(const UserId('u-import'))
          ..activate(ImportWorld.clubId, Role.director);
        return FirestoreClubImportStore(ClubStore(documents, scope), scope);
      }

      test('a stale cache does not make the marker look older', () async {
        final documents = _StaleCacheStore()
          ..seed(path, marker(4))
          ..cache[path] = marker(1);
        final store = storeOver(documents);

        expect((await store.readMarker(fingerprint))!.done, 4);
        expect((await store.inventory(fingerprint)).marker!.done, 4);
      });

      test('a cache that still holds a marker the server no longer has does '
          'not invent one', () async {
        final documents = _StaleCacheStore()..cache[path] = marker(2);
        final store = storeOver(documents);

        expect(await store.readMarker(fingerprint), isNull);
      });

      test('offline is an explicit failure, not the cached marker', () async {
        final documents = _StaleCacheStore()
          ..seed(path, marker(4))
          ..cache[path] = marker(4)
          ..failing = StoreFailureCode.unavailable;
        final store = storeOver(documents);

        for (final read in <Future<Object?> Function()>[
          () => store.readMarker(fingerprint),
          () => store.inventory(fingerprint),
        ]) {
          await expectLater(
            read(),
            throwsA(
              isA<ServiceFailure>().having(
                (f) => f.code,
                'code',
                ServiceFailureCode.unavailable,
              ),
            ),
          );
        }
      });
    });

    test('an empty club costs no more than one query per collection', () async {
      final world = ImportWorld.open()..act(Role.director);
      await world.importStore.inventory('f' * 64);
      expect(world.server.queryLog, isEmpty);
    });

    test('a teacher reads one group at a time, never the whole club', () async {
      final world = await imported();
      final server = world.server..queryLog.clear();
      final teacher = ImportWorld.open();
      server.documents.forEach(teacher.server.seed);
      teacher.act(Role.teacher, groups: ['g1']);
      final inventory = await teacher.importStore.inventory('f' * 64);
      expect(inventory.groups.keys.map((g) => g.value), ['g1']);
      expect(inventory.students.keys, hasLength(3));
      expect(
        inventory.existing[ImportCategory.attempts],
        hasLength(backup.attemptsOf(backup.studentId(1, 1)).length * 3),
      );
      final filters = teacher.server.queryLog;
      expect(filters, isNotEmpty);
      expect(
        filters.every(
          (f) =>
              (f is FieldEquals && f.field == 'groupId' && f.value == 'g1') ||
              (f is FieldArrayContainsAny && f.field == 'groupIds'),
        ),
        isTrue,
        reason: '$filters',
      );
    });

    test(
      'a teacher of more than 30 groups reads the students 30 groups at a time',
      () async {
        final groups = [for (var i = 0; i < 31; i++) 'tg$i'];
        final teacher = ImportWorld.open()
          ..seed('clubs/c1/students/s-first', {
            'firstName': 'A',
            'groupIds': ['tg0'],
          })
          ..seed('clubs/c1/students/s-last', {
            'firstName': 'B',
            'groupIds': ['tg30'],
          })
          ..act(Role.teacher, groups: groups);
        final inventory = await teacher.importStore.inventory('f' * 64);
        expect(inventory.students.keys.map((s) => s.value).toSet(), {
          's-first',
          's-last',
        });
        final sizes = [
          for (final f in teacher.server.queryLog)
            if (f is FieldArrayContainsAny) f.values.length,
        ];
        expect(sizes, [30, 1]);
      },
    );

    test('a marker whose role is unknown is a malformed document', () async {
      final world = ImportWorld.open()
        ..act(Role.director)
        ..seed('clubs/c1/imports/${'f' * 64}_u-import', {
          'fileId': 'f' * 64,
          'planId': 'p' * 64,
          'lots': 2,
          'done': 1,
          'writes': 3,
          'restored': 0,
          'role': 'pirate',
        });
      await expectLater(
        world.importStore.readMarker('f' * 64),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.other,
          ),
        ),
      );
    });

    test('students being erased are listed', () async {
      final world = ImportWorld.open()
        ..act(Role.director)
        ..seed('clubs/c1/students/s9', {
          'firstName': 'x',
          'groupIds': <String>[],
          'erasing': true,
        });
      final inventory = await world.importStore.inventory('f' * 64);
      expect(inventory.erasingStudents, {const StudentId('s9')});
    });

    test('a parent or a student cannot read for an import', () async {
      final world = ImportWorld.open()..act(Role.guardian);
      expect(
        world.importStore.inventory('f' * 64),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );
    });
  });

  group('failures', () {
    test('a server that does not answer in time is an interruption', () async {
      final scope = SessionScope()
        ..signIn(const UserId('u'))
        ..activate(ImportWorld.clubId, Role.director);
      final silent = _SilentStore();
      final store = FirestoreClubImportStore(
        ClubStore(silent, scope),
        scope,
        ackTimeout: const Duration(milliseconds: 20),
      );
      final world = ImportWorld.open()
        ..act(Role.director)
        ..backup = backup
        ..content = backup.content;
      world.decisions = world.createAll();
      final plan = await world.prepare();
      await expectLater(
        store.commit(
          ImportLotCommit(
            lot: plan.lots.first,
            marker: ImportMarker(
              fileId: plan.fingerprint,
              planId: plan.planId,
              lots: plan.lots.length,
              done: 1,
              writes: plan.totalWrites,
              restored: 0,
              role: Role.director,
            ),
            createsMarker: true,
            inventory: ClubInventory.empty,
          ),
        ),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.unavailable,
          ),
        ),
      );
    });

    test('a refusal of the rules is a denied failure', () async {
      final world = await imported();
      // Rejouer le premier lot comme un premier lot : le marqueur existe déjà.
      final plan = world.plan!;
      final replay = ImportLotCommit(
        lot: plan.lots.first,
        marker: ImportMarker(
          fileId: plan.fingerprint,
          planId: plan.planId,
          lots: plan.lots.length,
          done: 1,
          writes: plan.totalWrites,
          restored: 0,
          role: Role.director,
        ),
        createsMarker: true,
        inventory: ClubInventory.empty,
      );
      await expectLater(
        world.importStore.commit(replay),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );
    });
  });

  group('on the real document store (fake Firestore)', () {
    Future<void> settle() => pumpEventQueue();

    test(
      'the whole file comes back as written, attempts in file order',
      () async {
        final firestore = FakeFirebaseFirestore();
        final scope = SessionScope()
          ..signIn(const UserId('u-dir'))
          ..activate(ImportWorld.clubId, Role.director);
        final club = ClubStore(
          FirestoreDocumentStore(
            access: FirestoreSdkAccess(firestore: () => firestore),
          ),
          scope,
        );
        final world = ImportWorld.open()
          ..act(Role.director)
          ..backup = backup
          ..content = backup.content;
        world.decisions = world.createAll();
        final store = FirestoreClubImportStore(club, scope);
        final plan = await _Preparing(world, store)();
        expect(
          plan.status,
          ImportStatus.ready,
          reason: '${plan.report.problems}',
        );
        final run = (await ClubImportRunner(store, world.dailyLedger)(
          plan,
          role: Role.director,
        )) as Ok<ImportRunResult>;
        expect(run.value.status, ImportRunStatus.completed);
        await settle();

        final file = backup.snapshot;
        expect(
          await FirestoreSeasonRepository(club).all(),
          unorderedEquals(file.seasons),
        );
        expect(
          {for (final g in await FirestoreGroupRepository(club).all()) g.id: g},
          {for (final g in file.groups) g.id: g},
        );
        expect(
          {
            for (final s in await FirestoreStudentRepository(club).all())
              s.id: s,
          },
          {for (final s in file.students) s.id: s},
        );
        expect(
          {
            for (final r in await FirestoreSessionRecordRepository(club).all())
              r.id: r,
          },
          {for (final r in file.sessionRecords) r.id: r},
        );
        expect([
          for (final a in await FirestoreAttemptRepository(club).all()) a,
        ], file.attempts);
        expect(
          await FirestoreAcquisitionRepository(club).all(),
          unorderedEquals(file.blockAcquisitions),
        );
        expect(
          await FirestoreAssessmentRepository(club).all(),
          unorderedEquals(file.assessments),
        );
        expect(
          await FirestoreAcknowledgementRepository(club, scope).all(),
          unorderedEquals(file.alertAcknowledgements!),
        );
        expect(
          await FirestoreSeasonArchiveRepository(club).all(),
          file.seasonArchives,
        );
        expect(
          await FirestoreSessionRepository(club).getAll(),
          unorderedEquals(file.plannedSessions),
        );
        final marker = await store.readMarker(plan.fingerprint);
        expect(marker!.state, ImportState.done);
      },
    );
  });
}

/// Prépare avec le magasin d'un autre club que le monde (le monde sert à lire
/// le fichier, le catalogue et les décisions).
class _Preparing {
  _Preparing(this.world, this.store);

  final ImportWorld world;
  final FirestoreClubImportStore store;

  Future<ClubImportPlan> call() async {
    final planned = await world.prepareUseCaseWith(store)(
      world.content!,
      decisions: world.decisions,
    );
    return switch (planned) {
      Ok(:final value) => value,
      Err(:final failure) => fail('$failure'),
    };
  }
}

/// Un stock dont le **cache local** diffère du serveur : `get` répond comme un
/// SDK qui sert son cache (périmé), `getFromServer` dit ce que le serveur a.
class _StaleCacheStore extends InMemoryDocumentStore {
  final Map<String, Fields> cache = {};

  @override
  Future<StoredDocument?> get(String path) {
    final cached = cache[path];
    return cached == null
        ? super.get(path)
        : Future.value(StoredDocument(path, cached));
  }
}

/// Un stock dont l'écriture ne répond jamais (réseau muet).
class _SilentStore extends InMemoryDocumentStore {
  @override
  Future<void> commit(List<WriteOp> operations) => Completer<void>().future;
}
