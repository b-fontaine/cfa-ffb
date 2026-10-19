import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/firestore_world.dart';

Group _group(
  String id, {
  String name = 'Jeunes',
  Audience audience = Audience.children,
}) => Group(
  id: GroupId(id),
  seasonId: const SeasonId('se1'),
  name: name,
  audience: audience,
);

Group _admit(Group group, String student, DateTime from) => group.admit(
  studentId: StudentId(student),
  studentAudience: Audience.children,
  from: from,
);

/// Un stock où un autre gestionnaire écrit entre la lecture et notre lot.
class _RacingStore extends InMemoryDocumentStore {
  List<WriteOp>? concurrent;

  @override
  Future<void> commit(List<WriteOp> operations) async {
    final other = concurrent;
    if (other != null) {
      concurrent = null;
      await super.commit(other);
    }
    await super.commit(operations);
  }
}

void main() {
  late FirestoreWorld world;
  late FirestoreGroupRepository repository;
  final sept = DateTime(2026, 9);

  void student(String id, List<String> groups) => world.documents.seed(
    'clubs/c1/students/$id',
    {'firstName': id, 'groupIds': groups},
  );

  setUp(() {
    world = FirestoreWorld()..act('c1', Role.director);
    repository = FirestoreGroupRepository(world.club);
  });

  group('documents', () {
    test('the audience of the group is written as is', () async {
      await repository.save(_group('g1', audience: Audience.adults));

      expect(world.documents.read('clubs/c1/groups/g1')!['audience'], 'adults');
    });

    test('a new group carries exactly the fields the rules allow', () async {
      await repository.save(_group('g1'));

      expect(world.documents.read('clubs/c1/groups/g1'), {
        'seasonId': 'se1',
        'name': 'Jeunes',
        'audience': 'children',
        'teacherUids': <String>[],
      });
    });

    test(
      'saving again never replaces the teachers the director chose',
      () async {
        world.documents.seed('clubs/c1/groups/g1', {
          'seasonId': 'se1',
          'name': 'Ancien',
          'audience': 'children',
          'teacherUids': ['u-teacher-a'],
        });

        await repository.save(_group('g1', name: 'Nouveau'));

        final stored = world.documents.read('clubs/c1/groups/g1')!;
        expect(stored['name'], 'Nouveau');
        expect(stored['teacherUids'], ['u-teacher-a']);
      },
    );

    test(
      'a membership is one document with dated, denormalised fields',
      () async {
        final group = _admit(
          _group('g1'),
          's1',
          sept,
        ).release(studentId: const StudentId('s1'), to: DateTime.utc(2027));

        await repository.save(group);

        expect(world.paths, [
          'clubs/c1/groups/g1',
          'clubs/c1/memberships/g1_s1_2026-09-01T00:00:00.000',
        ]);
        expect(
          world.documents.read(
            'clubs/c1/memberships/g1_s1_2026-09-01T00:00:00.000',
          ),
          {
            'groupId': 'g1',
            'seasonId': 'se1',
            'studentId': 's1',
            'from': '2026-09-01T00:00:00.000',
            'to': '2027-01-01T00:00:00.000Z',
          },
        );
      },
    );

    test('an open membership has no end date', () async {
      await repository.save(_admit(_group('g1'), 's1', sept));

      expect(
        world.documents.read(
          'clubs/c1/memberships/g1_s1_2026-09-01T00:00:00.000',
        )!['to'],
        isNull,
      );
    });

    test('unchanged memberships are not written again', () async {
      final group = _admit(_admit(_group('g1'), 's1', sept), 's2', sept);
      await repository.save(group);
      final sent = <WriteOp>[];
      final recording = FirestoreGroupRepository(
        ClubStore(_Recording(world.documents, sent), world.scope),
      );

      await recording.save(group.rename('Autre'));

      expect(sent.map((op) => op.path), ['clubs/c1/groups/g1']);
      expect(sent.single, isA<UpdateOp>());
    });

    test('a membership removed from the group is deleted', () async {
      await repository.save(
        _admit(_admit(_group('g1'), 's1', sept), 's2', sept),
      );

      await repository.save(_admit(_group('g1'), 's2', sept));

      expect(world.paths.where((p) => p.contains('/memberships/')), [
        'clubs/c1/memberships/g1_s2_2026-09-01T00:00:00.000',
      ]);
    });

    test('a student in two groups from the same day keeps both', () async {
      await repository.save(_admit(_group('g1'), 's1', sept));
      await repository.save(_admit(_group('g2'), 's1', sept));

      expect(
        world.paths.where((p) => p.contains('/memberships/')),
        hasLength(2),
      );
      expect(await repository.idsEverContaining(const StudentId('s1')), {
        const GroupId('g1'),
        const GroupId('g2'),
      });
    });
  });

  group('current groups of the sheet (what the rules read)', () {
    test('a concurrent save of another group is not erased', () async {
      final racing = _RacingStore();
      final raceWorld = FirestoreWorld()..act('c1', Role.director);
      final club = ClubStore(racing, raceWorld.scope);
      racing
        ..seed('clubs/c1/students/s1', {
          'firstName': 's1',
          'groupIds': ['g9'],
        })
        ..concurrent = [
          const UpdateOp('clubs/c1/students/s1', {
            'groupIds': ArrayUnion(['g2']),
          }),
        ];

      await FirestoreGroupRepository(club)
          .save(_admit(_group('g1'), 's1', sept));

      expect(
        racing.read('clubs/c1/students/s1')!['groupIds'],
        unorderedEquals(['g9', 'g2', 'g1']),
      );
    });

    test('a concurrent release keeps the other groups too', () async {
      final racing = _RacingStore();
      final raceWorld = FirestoreWorld()..act('c1', Role.director);
      final club = ClubStore(racing, raceWorld.scope);
      racing
        ..seed('clubs/c1/students/s1', {
          'firstName': 's1',
          'groupIds': ['g1'],
        })
        ..concurrent = [
          const UpdateOp('clubs/c1/students/s1', {
            'groupIds': ArrayUnion(['g2']),
          }),
        ];
      final repository = FirestoreGroupRepository(club);
      final group = _admit(_group('g1'), 's1', sept);
      await repository.save(group);
      racing.concurrent = [
        const UpdateOp('clubs/c1/students/s1', {
          'groupIds': ArrayUnion(['g3']),
        }),
      ];

      await repository.save(
        group.release(studentId: const StudentId('s1'), to: DateTime(2027)),
      );

      expect(
        racing.read('clubs/c1/students/s1')!['groupIds'],
        unorderedEquals(['g2', 'g3']),
      );
    });

    test('a malformed groupIds is a service failure, not a crash', () async {
      world.documents.seed('clubs/c1/students/s1', {
        'firstName': 's1',
        'groupIds': 'oops',
      });

      await expectLater(
        repository.save(_admit(_group('g1'), 's1', sept)),
        throwsA(isA<ServiceFailure>()),
      );
    });

    test('admitting adds the group, leaving the others alone', () async {
      student('s1', ['g9']);

      await repository.save(_admit(_group('g1'), 's1', sept));

      expect(world.documents.read('clubs/c1/students/s1')!['groupIds'], [
        'g9',
        'g1',
      ]);
    });

    test('releasing removes the group, and only that one', () async {
      student('s1', ['g9']);
      final group = _admit(_group('g1'), 's1', sept);
      await repository.save(group);

      await repository.save(
        group.release(studentId: const StudentId('s1'), to: DateTime(2027)),
      );

      expect(world.documents.read('clubs/c1/students/s1')!['groupIds'], ['g9']);
    });

    test('an unchanged group and student sheet write nothing at all', () async {
      student('s1', ['g1']);
      final group = _admit(_group('g1'), 's1', sept);
      await repository.save(group);
      world.documents.commits = 0;

      await repository.save(group);

      expect(world.documents.commits, 0);
      expect(world.documents.read('clubs/c1/students/s1')!['groupIds'], ['g1']);
    });

    test('a renamed group is written, the other fields are kept', () async {
      student('s1', ['g1']);
      final group = _admit(_group('g1'), 's1', sept);
      await repository.save(group);

      await repository.save(group.rename('Nouveau'));

      final stored = world.documents.read('clubs/c1/groups/g1')!;
      expect(stored['name'], 'Nouveau');
      expect(stored['teacherUids'], <String>[]);
    });

    test('a student with no sheet yet is skipped, not an error', () async {
      await repository.save(_admit(_group('g1'), 's1', sept));

      expect(world.documents.read('clubs/c1/students/s1'), isNull);
    });

    test('deleting the group retires it from every sheet', () async {
      student('s1', ['g1', 'g2']);
      student('s2', ['g1']);
      await repository.save(
        _admit(_admit(_group('g1'), 's1', sept), 's2', sept),
      );

      await repository.delete(const GroupId('g1'));

      expect(world.documents.read('clubs/c1/students/s1')!['groupIds'], ['g2']);
      expect(
        world.documents.read('clubs/c1/students/s2')!['groupIds'],
        isEmpty,
      );
      expect(world.paths, ['clubs/c1/students/s1', 'clubs/c1/students/s2']);
    });
  });

  group('erasing a student', () {
    test("removes their memberships in every group, nobody else's", () async {
      await repository.save(
        _admit(_admit(_group('g1'), 's1', sept), 's2', sept),
      );
      await repository.save(_admit(_group('g2'), 's1', sept));

      await repository.eraseStudent(const StudentId('s1'));

      expect(world.paths.where((p) => p.contains('/memberships/')), [
        'clubs/c1/memberships/g1_s2_2026-09-01T00:00:00.000',
      ]);
      final group = (await repository.byId(const GroupId('g1')))!;
      expect([for (final m in group.memberships) m.studentId.value], ['s2']);
    });

    test('is harmless for a student with no membership', () async {
      await repository.eraseStudent(const StudentId('nobody'));

      expect(world.documents.commits, 0);
      expect(world.paths, isEmpty);
    });
  });

  group('club scope', () {
    test("clubs never see each other's groups", () async {
      await repository.save(_admit(_group('g1'), 's1', sept));
      world.act('c2', Role.director);

      expect(await repository.all(), isEmpty);
      expect(await repository.byId(const GroupId('g1')), isNull);
      expect(
        await repository.idsEverContaining(const StudentId('s1')),
        isEmpty,
      );
      await repository.save(_group('g1', name: 'Autre club'));
      world.act('c1', Role.director);

      expect((await repository.byId(const GroupId('g1')))!.name, 'Jeunes');
    });

    test('without an active club nothing is read or written', () async {
      world.scope.deactivateClub();

      await expectLater(repository.all(), throwsA(isA<ServiceFailure>()));
      await expectLater(
        repository.save(_group('g1')),
        throwsA(isA<ServiceFailure>()),
      );
      await expectLater(
        repository.delete(const GroupId('g1')),
        throwsA(isA<ServiceFailure>()),
      );
      await expectLater(
        repository.idsEverContaining(const StudentId('s1')),
        throwsA(isA<ServiceFailure>()),
      );
      expect(world.documents.reads + world.documents.commits, 0);
    });

    test('more than 500 writes are sent in several batches', () async {
      var group = _group('g1');
      for (var i = 0; i < 600; i++) {
        group = _admit(group, 's$i', sept);
      }

      await repository.save(group);

      expect(world.documents.commits, 2);
      expect(
        (await repository.byId(const GroupId('g1')))!.memberships,
        hasLength(600),
      );
    });
  });

  group('all and byId, by role', () {
    setUp(() async {
      await repository.save(_admit(_group('g1'), 's1', sept));
      await repository.save(_admit(_group('g2', name: 'Adultes'), 's2', sept));
      world.documents.reads = 0;
    });

    test('a director reads the club in two reads', () async {
      expect(
        [for (final g in await repository.all()) g.id.value],
        ['g1', 'g2'],
      );
      expect(world.documents.reads, 2);
    });

    test(
      'a teacher reads the groups of their member, with memberships',
      () async {
        world.act('c1', Role.teacher, groups: ['g2', 'g1', 'g9']);

        final all = await repository.all();

        expect([for (final g in all) g.id.value], ['g1', 'g2']);
        expect(all.first.memberships, hasLength(1));
      },
    );

    test('a parent reads their groups without the other students', () async {
      world.act('c1', Role.guardian, groups: ['g1']);

      final all = await repository.all();

      expect([for (final g in all) g.name], ['Jeunes']);
      expect(all.single.memberships, isEmpty);
      expect(
        (await repository.byId(const GroupId('g1')))!.memberships,
        isEmpty,
      );
    });

    test('a refusal is a denied failure, a network loss unavailable', () async {
      world.documents.failing = StoreFailureCode.permissionDenied;
      await expectLater(
        repository.byId(const GroupId('g1')),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );
      world.documents.failing = StoreFailureCode.unavailable;
      await expectLater(
        repository.all(),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.unavailable,
          ),
        ),
      );
    });
  });

  test(
    'a group document of the wrong shape is a failure, not a guess',
    () async {
      world.documents.seed('clubs/c1/groups/g1', {'name': 'x'});
      world.documents.seed('clubs/c1/groups/g2', {
        'seasonId': 'se1',
        'name': 'x',
        'audience': 'seniors',
      });
      world.documents.seed('clubs/c1/groups/g3', {
        'seasonId': 'se1',
        'name': ' ',
        'audience': 'children',
      });

      for (final id in ['g1', 'g2', 'g3']) {
        await expectLater(
          repository.byId(GroupId(id)),
          throwsA(isA<ServiceFailure>()),
          reason: id,
        );
      }
    },
  );
}

/// Un stock qui retient les écritures envoyées.
class _Recording implements DocumentStore {
  _Recording(this._inner, this.sent);

  final InMemoryDocumentStore _inner;
  final List<WriteOp> sent;

  @override
  Future<StoredDocument?> get(String path) => _inner.get(path);

  @override
  Future<StoredDocument?> peek(String path) => _inner.peek(path);

  @override
  Future<List<StoredDocument>> list(String collection) =>
      _inner.list(collection);

  @override
  Future<List<StoredDocument>> query(String collection, QueryFilter filter) =>
      _inner.query(collection, filter);

  @override
  Future<List<StoredDocument>> collectionGroup(
    String collectionId, {
    required String field,
    required Object? equalTo,
  }) => _inner.collectionGroup(collectionId, field: field, equalTo: equalTo);

  @override
  Future<bool> createIfAbsent(String path, Fields fields) =>
      _inner.createIfAbsent(path, fields);

  @override
  Future<void> commit(List<WriteOp> operations) {
    sent.addAll(operations);
    return _inner.commit(operations);
  }
}
