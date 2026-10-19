import 'package:billard_cfa/entities/season/data/firestore_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/firestore_world.dart';

class _Spy extends InMemoryDocumentStore {
  final List<WriteOp> sent = [];
  final List<String> created = [];

  @override
  Future<bool> createIfAbsent(String path, Fields fields) {
    created.add(path);
    return super.createIfAbsent(path, fields);
  }

  @override
  Future<void> commit(List<WriteOp> operations) {
    sent.addAll(operations);
    return super.commit(operations);
  }
}

/// Hors ligne : seuls les documents du cache se lisent (la lecture d'un
/// document **absent** échoue, `unavailable`) et la transaction de création
/// ne peut pas se faire ; les écritures, elles, partent dans la file.
class _OfflineSpy extends _Spy {
  @override
  Future<StoredDocument?> get(String path) async {
    final found = await super.get(path);
    if (found == null) {
      throw const StoreFailure(StoreFailureCode.unavailable, 'hors ligne');
    }
    return found;
  }

  @override
  Future<bool> createIfAbsent(String path, Fields fields) =>
      throw const StoreFailure(StoreFailureCode.unavailable, 'hors ligne');
}

/// Rejoue la règle de création des saisies : un `set` qui écrit `createdAt`
/// (date du serveur) sur un document qui **existe** change la date, donc est
/// refusé ; le reste est accepté. `denyAll` refuse tout (membre sans droit).
class _RulesLikeSpy extends _OfflineSpy {
  int refused = 0;
  bool denyAll = false;

  /// Le cache de l'appareil ne connaît rien (cache froid) : `peek` rend `null`
  /// même quand le serveur a le document.
  bool coldCache = false;

  @override
  Future<StoredDocument?> peek(String path) async =>
      coldCache ? null : await super.peek(path);

  @override
  Future<StoredDocument?> get(String path) async => await super.peek(path);

  @override
  Future<void> commit(List<WriteOp> operations) {
    for (final op in operations) {
      final recreates =
          op is SetOp &&
          op.fields['createdAt'] is ServerTimestamp &&
          read(op.path) != null;
      if (denyAll || recreates) {
        refused++;
        throw const StoreFailure(StoreFailureCode.permissionDenied);
      }
    }
    return super.commit(operations);
  }
}

/// Rejoue le refus des règles : une liste de présents de plus de
/// `maxPresentStudents` (`recordShape`) est refusée, sans message précis.
class _BoundedSpy extends _Spy {
  @override
  Future<void> commit(List<WriteOp> operations) {
    for (final op in operations.whereType<UpdateOp>()) {
      final union = op.fields['presentStudentIds'];
      if (union is ArrayUnion) {
        final stored = read(op.path)?['presentStudentIds'] as List? ?? const [];
        if ({...stored, ...union.values}.length > maxPresentStudents) {
          throw const StoreFailure(StoreFailureCode.permissionDenied);
        }
      }
    }
    return super.commit(operations);
  }
}

/// Une saison donnée telle que le serveur la stocke.
Fields _storedSitting(List<String> present) => {
  'groupId': 'g1',
  'seasonId': 'se1',
  'date': '2026-10-03T00:00:00.000',
  'audience': 'children',
  'mainBlockId': null,
  'recallBlockId': null,
  'sheetId': 'p',
  'tags': <String>[],
  'presentStudentIds': present,
  'createdAt': DateTime(2026, 10, 3, 18),
};

Season _season() => Season(
  id: const SeasonId('se1'),
  label: '2026-2027',
  startDate: DateTime(2026, 9),
  endDate: DateTime(2027, 6, 30),
);

SessionRecord _record(
  String id, {
  String group = 'g1',
  Set<String> present = const {},
  SheetId? sheet,
}) => SessionRecord(
  id: SessionId(id),
  groupId: GroupId(group),
  seasonId: const SeasonId('se1'),
  date: DateTime(2026, 10, 3),
  audience: Audience.children,
  present: {for (final s in present) StudentId(s)},
  sheetId: sheet,
);

void main() {
  late FirestoreWorld world;

  setUp(() {
    world = FirestoreWorld()..act('c1', Role.director);
    world.documents.serverNow = () => DateTime(2026, 10, 12);
    world.documents
      ..seed('clubs/c1/groups/g1', {'seasonId': 'se1', 'name': 'A'})
      ..seed('clubs/c1/groups/g2', {'seasonId': 'se2', 'name': 'B'});
  });

  group('FirestoreSeasonRepository', () {
    test('writes exactly the fields the rules allow', () async {
      await FirestoreSeasonRepository(world.club).save(_season());

      expect(world.documents.read('clubs/c1/seasons/se1'), {
        'label': '2026-2027',
        'startDate': '2026-09-01T00:00:00.000',
        'endDate': '2027-06-30T00:00:00.000',
        'closedOn': null,
        'createdAt': DateTime(2026, 10, 12),
      });
    });

    test('an unchanged season is not written again', () async {
      final repository = FirestoreSeasonRepository(world.club);
      await repository.save(_season());
      final before = world.documents.commits;

      await repository.save(_season());

      expect(world.documents.commits, before);
    });

    test('a changed season keeps its creation date', () async {
      final repository = FirestoreSeasonRepository(world.club);
      await repository.save(_season());
      world.documents.serverNow = () => DateTime(2027);

      await repository.save(
        _season().copyWith(closedOn: DateTime(2027, 6, 30)),
      );

      final stored = world.documents.read('clubs/c1/seasons/se1')!;
      expect(stored['createdAt'], DateTime(2026, 10, 12));
      expect(stored['closedOn'], '2027-06-30T00:00:00.000');
    });
  });

  group('FirestoreSessionRepository', () {
    late FirestoreSessionRepository repository;
    setUp(() => repository = FirestoreSessionRepository(world.club));

    Session session({String? group = 'g1'}) => Session(
      id: 'p1',
      title: 'Posture',
      date: DateTime(2026, 10, 5),
      audience: Audience.children,
      groupId: group == null ? null : GroupId(group),
      sheetId: SheetId('posture-1'),
    );

    test(
      'writes the fields the rules allow, the season of the group',
      () async {
        await repository.add(session());

        expect(world.documents.read('clubs/c1/sessions/p1'), {
          'groupId': 'g1',
          'seasonId': 'se1',
          'title': 'Posture',
          'date': '2026-10-05T00:00:00.000',
          'audience': 'children',
          'sheetId': 'posture-1',
          'createdAt': DateTime(2026, 10, 12),
        });
      },
    );

    test('a session without group is only a defensive failure: the rule is in '
        'PlanSession', () async {
      await expectLater(
        repository.add(session(group: null)),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.other,
          ),
        ),
      );
      expect(world.documents.commits, 0);
    });

    test(
      'a group missing from the store is a service failure, not a rule',
      () async {
        await expectLater(
          repository.add(session(group: 'zz')),
          throwsA(
            isA<ServiceFailure>().having(
              (f) => f.code,
              'code',
              ServiceFailureCode.other,
            ),
          ),
        );
        expect(world.documents.commits, 0);
      },
    );

    test('a teacher, a parent and a student ask one group at a time', () async {
      await repository.add(session());
      for (final role in [Role.teacher, Role.guardian, Role.student]) {
        world
          ..act('c1', role, groups: ['g1', 'g2'])
          ..documents.queryLog.clear();

        final all = await repository.getAll();

        expect(all.map((s) => s.id), ['p1'], reason: role.name);
        expect(
          [
            for (final f in world.documents.queryLog)
              (f.field, (f as FieldEquals).value),
          ],
          [('groupId', 'g1'), ('groupId', 'g2')],
          reason: role.name,
        );
      }
    });

    test('a director lists the club in one read', () async {
      await repository.add(session());
      world.documents
        ..reads = 0
        ..queryLog.clear();

      await repository.getAll();

      expect(world.documents.reads, 1);
      expect(world.documents.queryLog, isEmpty);
    });
  });

  group('FirestoreSessionRecordRepository', () {
    late FirestoreSessionRecordRepository repository;
    setUp(() => repository = FirestoreSessionRecordRepository(world.club));

    test('writes the fields the rules allow, closed-list tags only', () async {
      await repository.save(
        _record('x1', present: {'s2', 's1'}).copyWith(
          mainBlockId: 'a',
          sheetId: SheetId('posture-1'),
          tags: {SessionTag.toRedo, SessionTag.gameAppreciated},
        ),
      );

      expect(world.documents.read('clubs/c1/records/x1'), {
        'groupId': 'g1',
        'seasonId': 'se1',
        'date': '2026-10-03T00:00:00.000',
        'audience': 'children',
        'mainBlockId': 'a',
        'recallBlockId': null,
        'sheetId': 'posture-1',
        'tags': ['gameAppreciated', 'toRedo'],
        'presentStudentIds': ['s1', 's2'],
        'createdAt': DateTime(2026, 10, 12),
      });
    });

    test('saving again keeps the creation date', () async {
      await repository.save(_record('x1'));
      world.documents.serverNow = () => DateTime(2027);

      await repository.save(_record('x1', present: {'s1'}));

      expect(
        world.documents.read('clubs/c1/records/x1')!['createdAt'],
        DateTime(2026, 10, 12),
      );
    });

    test('two concurrent openings keep the first creation date and send '
        'createdAt only with a creation', () async {
      final spy = _Spy();
      var calls = 0;
      spy.serverNow = () =>
          DateTime(2026, 10, 12).add(Duration(minutes: calls++));
      final records = FirestoreSessionRecordRepository(
        ClubStore(spy, world.scope),
      );

      await Future.wait([
        records.open(
          _record('g1_20261003_p', present: {'s1'}, sheet: SheetId('p')),
        ),
        records.open(
          _record('g1_20261003_p', present: {'s2'}, sheet: SheetId('p')),
        ),
      ]);

      final stored = spy.read('clubs/c1/records/g1_20261003_p')!;
      expect(stored['createdAt'], DateTime(2026, 10, 12));
      expect(stored['presentStudentIds'], ['s1', 's2']);
      expect(spy.created, hasLength(2));
      for (final op in spy.sent) {
        final fields = op is UpdateOp ? op.fields : (op as SetOp).fields;
        expect(fields.containsKey('createdAt'), isFalse, reason: '$op');
      }
    });

    test(
      'opening an existing sitting unions the presents server side',
      () async {
        final spy = _Spy();
        final records = FirestoreSessionRecordRepository(
          ClubStore(spy, world.scope),
        );
        await records.open(_record('x1', present: {'s1'}));
        spy.sent.clear();

        await records.open(_record('x1', present: {'s2'}));

        final op = spy.sent.single as UpdateOp;
        expect(op.fields.keys, ['presentStudentIds']);
        expect(op.fields['presentStudentIds'], isA<ArrayUnion>());
      },
    );

    test('resuming replaces the presents and sends no tags', () async {
      final spy = _Spy();
      final records = FirestoreSessionRecordRepository(
        ClubStore(spy, world.scope),
      );
      await records.save(_record('x1', present: {'s1'}));
      spy.sent.clear();

      await records.resume(
        _record('x1', present: {'s2'}).copyWith(mainBlockId: 'a'),
      );

      final op = spy.sent.single as UpdateOp;
      expect(op.fields['presentStudentIds'], ['s2']);
      expect(op.fields.containsKey('tags'), isFalse);
      expect(op.fields.containsKey('createdAt'), isFalse);
      expect(spy.read('clubs/c1/records/x1')!['presentStudentIds'], ['s2']);
    });

    test(
      'a free sitting is created offline, createdAt only with the creation',
      () async {
        final spy = _OfflineSpy();
        final records = FirestoreSessionRecordRepository(
          ClubStore(spy, world.scope),
        );

        final opened = await records.open(_record('x1', present: {'s1'}));
        await records.save(_record('x1', present: {'s1', 's2'}));

        expect(opened.id, const SessionId('x1'));
        final first = spy.sent.first as SetOp;
        expect(first.fields['createdAt'], isA<ServerTimestamp>());
        expect(first.merge, isTrue);
        final second = spy.sent.last as SetOp;
        expect(second.fields.containsKey('createdAt'), isFalse);
        expect(spy.read('clubs/c1/records/x1')!['presentStudentIds'], [
          's1',
          's2',
        ]);
      },
    );

    group('a sitting linked to a catalogue sheet, created offline', () {
      const path = 'clubs/c1/records/g1_20261003_p';

      ClubStore offlineClub(
        _Spy spy, {
        required InMemoryConnectivityStatus network,
        required SendTracker sends,
      }) => ClubStore(
        spy,
        world.scope,
        sends: sends,
        network: network,
        ackGrace: const Duration(milliseconds: 20),
      );

      late InMemoryConnectivityStatus network;
      late SendTracker sends;

      setUp(() {
        network = InMemoryConnectivityStatus();
        sends = SendTracker(InMemoryPendingWritesProbe());
      });

      SessionRecord linked(Set<String> present) =>
          _record('g1_20261003_p', present: present, sheet: SheetId('p'));

      test('with the network down, no transaction is tried: one plain write, '
          'createdAt from the server', () async {
        network.setOnline(value: false);
        final spy = _OfflineSpy();
        final records = FirestoreSessionRecordRepository(
          offlineClub(spy, network: network, sends: sends),
        );

        final opened = await records.open(linked({'s1'}));

        expect(opened.present, {const StudentId('s1')});
        expect(spy.created, isEmpty);
        final write = spy.sent.single as SetOp;
        expect(write.path, path);
        expect(write.merge, isTrue);
        expect(write.fields['createdAt'], isA<ServerTimestamp>());
        expect(write.fields['presentStudentIds'], ['s1']);
      });

      test('the transaction is tried when the network is not known down, '
          'and an unreachable server falls back to the plain write', () async {
        final spy = _OfflineSpy();
        final records = FirestoreSessionRecordRepository(
          offlineClub(spy, network: network, sends: sends),
        );

        await records.open(linked({'s1'}));

        expect(spy.sent.single, isA<SetOp>());
        expect(spy.read(path)!['presentStudentIds'], ['s1']);
      });

      test('online it is still the transaction, and nothing else', () async {
        final spy = _Spy();
        final records = FirestoreSessionRecordRepository(
          offlineClub(spy, network: network, sends: sends),
        );

        await records.open(linked({'s1'}));

        expect(spy.created, [path]);
        expect(spy.sent, isEmpty);
      });

      test(
        'another device created the sitting meanwhile: the plain write is '
        'refused, the presents are united instead, nothing is reported',
        () async {
          network.setOnline(value: false);
          final spy = _RulesLikeSpy()
            ..coldCache = true
            ..seed(path, _storedSitting(['s2']));
          final records = FirestoreSessionRecordRepository(
            offlineClub(spy, network: network, sends: sends),
          );

          await records.open(linked({'s1'}));
          await pumpEventQueue();

          expect(spy.refused, 1);
          expect((spy.read(path)!['presentStudentIds']! as List).toSet(), {
            's1',
            's2',
          });
          expect(spy.read(path)!['createdAt'], DateTime(2026, 10, 3, 18));
          expect(sends.hasFailure, isFalse);
          expect(sends.pending, 0);
        },
      );

      test('both devices create it offline: whoever arrives second is '
          'united, in any order', () async {
        network.setOnline(value: false);
        final spy = _RulesLikeSpy();
        final first = FirestoreSessionRecordRepository(
          offlineClub(spy, network: network, sends: sends),
        );
        final second = FirestoreSessionRecordRepository(
          offlineClub(
            spy,
            network: network,
            sends: SendTracker(InMemoryPendingWritesProbe()),
          ),
        );

        await Future.wait([
          first.open(linked({'s1'})),
          second.open(linked({'s2'})),
        ]);
        await pumpEventQueue();

        expect((spy.read(path)!['presentStudentIds']! as List).toSet(), {
          's1',
          's2',
        });
        expect(spy.created, isEmpty);
      });

      test(
        'a sitting the cache already knows is united, never re-created',
        () async {
          network.setOnline(value: false);
          final spy = _OfflineSpy()..seed(path, _storedSitting(['s2']));
          final records = FirestoreSessionRecordRepository(
            offlineClub(spy, network: network, sends: sends),
          );

          await records.open(linked({'s1'}));

          final write = spy.sent.single as UpdateOp;
          expect(write.fields.keys, ['presentStudentIds']);
          expect(write.fields['presentStudentIds'], isA<ArrayUnion>());
        },
      );

      test('a genuine refusal (not a member of the group) is reported, the '
          'union is refused too', () async {
        network.setOnline(value: false);
        final spy = _RulesLikeSpy()..denyAll = true;
        final records = FirestoreSessionRecordRepository(
          offlineClub(spy, network: network, sends: sends),
        );

        await records.open(linked({'s1'}));
        await pumpEventQueue();

        expect(sends.hasFailure, isTrue);
        expect(sends.lastFailure!.code, StoreFailureCode.permissionDenied);
      });
    });

    test('two devices whose presents together exceed the maximum are told so '
        'instead of a generic refusal', () async {
      final spy = _BoundedSpy();
      final records = FirestoreSessionRecordRepository(
        ClubStore(spy, world.scope),
      );
      Set<String> students(int from, int to) => {
        for (var i = from; i < to; i++) 's$i',
      };
      await records.open(_record('x1', present: students(0, 40)));

      await expectLater(
        records.open(_record('x1', present: students(40, 70))),
        throwsA(
          isA<InvariantViolation>().having(
            (f) => f.code,
            'code',
            InvariantCode.tooManyPresent,
          ),
        ),
      );
      expect(
        spy.read('clubs/c1/records/x1')!['presentStudentIds'],
        hasLength(40),
      );
    });

    test(
      'a refusal that is not about the size stays a service failure',
      () async {
        final spy = _BoundedSpy();
        final records = FirestoreSessionRecordRepository(
          ClubStore(spy, world.scope),
        );
        await records.open(_record('x1', present: {'s1'}));
        spy.failing = StoreFailureCode.permissionDenied;

        await expectLater(
          records.open(_record('x1', present: {'s2'})),
          throwsA(isA<ServiceFailure>()),
        );
      },
    );

    test(
      'saving a sitting that already exists never sends createdAt',
      () async {
        final spy = _Spy();
        final records = FirestoreSessionRecordRepository(
          ClubStore(spy, world.scope),
        );
        await records.save(_record('x1'));
        spy.sent.clear();

        await records.save(_record('x1', present: {'s1'}));

        expect(
          (spy.sent.single as SetOp).fields.containsKey('createdAt'),
          isFalse,
        );
      },
    );

    test('an unknown tag code of a stored document is ignored', () async {
      world.documents.seed('clubs/c1/records/x9', {
        'groupId': 'g1',
        'seasonId': 'se1',
        'date': '2026-10-03T00:00:00.000',
        'audience': 'children',
        'tags': ['toRedo', 'free text'],
        'presentStudentIds': <String>[],
      });

      final record = await repository.byId(const SessionId('x9'));

      expect(record!.tags, {SessionTag.toRedo});
    });

    test('a parent and a student read no record at all', () async {
      await repository.save(_record('x1', present: {'s1'}));
      for (final role in [Role.guardian, Role.student]) {
        world
          ..act('c1', role, groups: ['g1'], students: ['s1'])
          ..documents.reads = 0;

        expect(await repository.all(), isEmpty, reason: role.name);
        expect(await repository.forGroup(const GroupId('g1')), isEmpty);
        expect(await repository.forStudent(const StudentId('s1')), isEmpty);
        expect(world.documents.reads, 0, reason: 'aucune requête refusée');
      }
    });

    test('a teacher asks his groups one by one, never by student', () async {
      await repository.save(_record('x1', present: {'s1'}));
      await repository.save(_record('x2', group: 'g2', present: {'s1'}));
      await repository.save(_record('x3', present: {'s2'}));
      world
        ..act('c1', Role.teacher, groups: ['g1'])
        ..documents.queryLog.clear();

      final records = await repository.forStudent(const StudentId('s1'));

      expect(records.map((r) => r.id.value), ['x1']);
      expect(
        [for (final f in world.documents.queryLog) f],
        everyElement(
          isA<FieldEquals>().having((f) => f.field, 'field', 'groupId'),
        ),
      );
    });

    test('a teacher lists only his groups in `all()`', () async {
      await repository.save(_record('x1', present: {'s1'}));
      await repository.save(_record('x2', group: 'g2', present: {'s1'}));
      world
        ..act('c1', Role.teacher, groups: ['g1'])
        ..documents.queryLog.clear();

      final records = await repository.all();

      expect(records.map((r) => r.id.value), ['x1']);
      expect(
        [
          for (final f in world.documents.queryLog)
            (f.field, (f as FieldEquals).value),
        ],
        [('groupId', 'g1')],
      );
    });

    test('a director finds a student by presence in one query', () async {
      await repository.save(_record('x1', present: {'s1'}));
      world.documents.queryLog.clear();

      await repository.forStudent(const StudentId('s1'));

      expect(world.documents.queryLog.single, isA<FieldArrayContainsAny>());
    });

    test(
      'erasing a presence removes the id server side, nothing else',
      () async {
        final spy = _Spy()
          ..seed('clubs/c1/records/x1', {
            'groupId': 'g1',
            'presentStudentIds': ['s1', 's2'],
          });

        await FirestoreSessionRecordRepository(ClubStore(spy, world.scope))
            .eraseStudent(const StudentId('s1'));

        final op = spy.sent.single as UpdateOp;
        expect(op.path, 'clubs/c1/records/x1');
        expect(op.fields.keys, ['presentStudentIds']);
        expect(op.fields['presentStudentIds'], isA<ArrayRemove>());
        expect(spy.read('clubs/c1/records/x1')!['presentStudentIds'], ['s2']);
      },
    );
  });

  group('FirestoreSeasonArchiveRepository', () {
    test(
      'writes one summary per audience and one document per exercise',
      () async {
        final archive = SeasonArchive(
          seasonId: const SeasonId('se1'),
          audiences: [
            AudienceArchive(
              audience: Audience.children,
              sessionCount: 2,
              presenceCount: 5,
              possiblePresenceCount: 6,
              studentCount: 3,
              attemptCount: 4,
            ),
          ],
          exercises: [
            ExerciseArchive(
              audience: Audience.children,
              exercise: ExerciseRef(blockId: 'a', number: 1),
              studentCount: 3,
              attemptCount: 4,
              potted: 6,
              total: 20,
            ),
          ],
        );

        await FirestoreSeasonArchiveRepository(world.club).save(archive);

        expect(world.paths.where((p) => p.contains('/archives/')), [
          'clubs/c1/archives/se1_children',
          'clubs/c1/archives/se1_children_a_1',
        ]);
        final exercise = world.documents.read(
          'clubs/c1/archives/se1_children_a_1',
        )!;
        expect(exercise.keys.toSet(), {
          'seasonId',
          'public',
          'blockId',
          'exerciseNumber',
          'studentCount',
          'attemptCount',
          'potted',
          'total',
          'createdAt',
        });
        expect(
          world.documents.read('clubs/c1/archives/se1_children')!.keys,
          isNot(anyOf(contains('groupId'), contains('studentId'))),
        );
      },
    );
  });
}
