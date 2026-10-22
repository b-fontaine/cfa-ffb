import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/data/store_student_directory.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_directory.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/firestore_world.dart';

Student _student(String id, String name, {DateTime? since}) => Student.enroll(
  id: StudentId(id),
  firstName: name,
  audience: Audience.children,
  since: since ?? DateTime(2026, 9),
);

/// Un stock dont la lecture ne voit pas les fiches (concurrence, cache hors
/// ligne sans le document) : l'écriture doit tenir seule sa garantie.
class _BlindStore extends InMemoryDocumentStore {
  @override
  Future<StoredDocument?> get(String path) async => null;
}

void main() {
  late FirestoreWorld world;
  late FirestoreStudentRepository repository;

  setUp(() {
    world = FirestoreWorld()..act('c1', Role.director);
    world.documents.serverNow = () => DateTime(2026, 10, 12);
    repository = FirestoreStudentRepository(world.club);
  });

  test('creates the sheet with the fields firestore.rules allows', () async {
    final student = _student(
      's1',
      'Léa',
    ).changeAudience(Audience.adults, DateTime.utc(2028, 9));

    await repository.create(student);

    expect(world.documents.read('clubs/c1/students/s1'), {
      'firstName': 'Léa',
      'audience': 'adults',
      'audienceHistory': [
        {'audience': 'children', 'effectiveFrom': '2026-09-01T00:00:00.000'},
        {'audience': 'adults', 'effectiveFrom': '2028-09-01T00:00:00.000Z'},
      ],
      'groupIds': <String>[],
      'createdAt': DateTime(2026, 10, 12),
    });
  });

  test('updating keeps the current groups and the creation date', () async {
    world.documents.seed('clubs/c1/students/s1', {
      'firstName': 'Léa',
      'audience': 'children',
      'groupIds': ['g1', 'g2'],
      'createdAt': DateTime(2026, 9, 2),
    });

    await repository.save(_student('s1', 'Léa-Rose'));

    final stored = world.documents.read('clubs/c1/students/s1')!;
    expect(stored['firstName'], 'Léa-Rose');
    expect(stored['groupIds'], ['g1', 'g2']);
    expect(stored['createdAt'], DateTime(2026, 9, 2));
  });

  test('a sheet the read cannot see is not reset by the save', () async {
    final blind = _BlindStore()
      ..seed('clubs/c1/students/s1', {
        'firstName': 'Léa',
        'audience': 'children',
        'groupIds': ['g1', 'g2'],
        'createdAt': DateTime(2026, 9, 2),
      });
    final blindWorld = FirestoreWorld()..act('c1', Role.director);

    await FirestoreStudentRepository(ClubStore(blind, blindWorld.scope))
        .save(_student('s1', 'Léa-Rose'));

    final stored = blind.read('clubs/c1/students/s1')!;
    expect(stored['firstName'], 'Léa-Rose');
    expect(stored['groupIds'], ['g1', 'g2']);
    expect(stored['audienceHistory'], isNotEmpty);
  });

  test('is the very document the directory publishes at invitation', () async {
    await StoreStudentDirectory(world.documents)
        .publish(const ClubId('c1'), const [
          PublishedStudent(
            id: StudentId('s1'),
            firstName: 'Léa',
            audience: Audience.children,
            groupIds: [GroupId('g1')],
          ),
        ]);
    expect(world.paths, ['clubs/c1/students/s1']);

    final published = (await repository.byId(const StudentId('s1')))!;
    expect(published.firstName, 'Léa');
    expect(published.audienceHistory, [
      AudienceChange(
        audience: Audience.children,
        effectiveFrom: DateTime(2026, 10, 12),
      ),
    ]);

    await repository.create(_student('s1', 'Léa'));

    expect(world.paths, ['clubs/c1/students/s1']);
    expect(world.documents.read('clubs/c1/students/s1')!['groupIds'], ['g1']);
  });

  test('delete and erase remove the document physically', () async {
    await repository.create(_student('s1', 'Léa'));
    await repository.create(_student('s2', 'Théo'));

    await repository.delete(const StudentId('s1'));
    await repository.erase(const StudentId('s2'));
    await repository.erase(const StudentId('unknown'));

    expect(world.paths, isEmpty);
  });

  test('lists by enrolment, then by id', () async {
    await repository.create(_student('b', 'B', since: DateTime(2026, 9)));
    await repository.create(_student('c', 'C', since: DateTime(2026, 8)));
    await repository.create(_student('a', 'A', since: DateTime(2026, 9)));

    expect(
      [for (final s in await repository.all()) s.id.value],
      ['c', 'a', 'b'],
    );
  });

  test('a club only sees its own students', () async {
    await repository.create(_student('s1', 'Léa'));
    world.act('c2', Role.director);

    expect(await repository.all(), isEmpty);
    expect(await repository.byId(const StudentId('s1')), isNull);
    await repository.create(_student('s1', 'Zoé'));
    world.act('c1', Role.director);

    expect((await repository.byId(const StudentId('s1')))!.firstName, 'Léa');
  });

  group('all, by role (what the rules let each role query)', () {
    setUp(() {
      for (final (id, groups) in [
        ('s1', ['g1']),
        ('s2', ['g2']),
        ('s3', ['g1', 'g3']),
        ('s4', <String>[]),
      ]) {
        world.documents.seed('clubs/c1/students/$id', {
          'firstName': id,
          'audience': 'children',
          'groupIds': groups,
          'createdAt': DateTime(2026, 9),
        });
      }
      world.documents.reads = 0;
    });

    test('a director lists the club', () async {
      expect(await repository.all(), hasLength(4));
      expect(world.documents.reads, 1);
    });

    test('an administrator lists the club too', () async {
      world.act('c1', Role.admin);

      expect(await repository.all(), hasLength(4));
    });

    test('a teacher queries the groupIds of their groups', () async {
      world.act('c1', Role.teacher, groups: ['g1']);

      expect(
        [for (final s in await repository.all()) s.id.value],
        ['s1', 's3'],
      );
    });

    test('a teacher of no group sees nobody, with no query', () async {
      world.act('c1', Role.teacher);

      expect(await repository.all(), isEmpty);
      expect(world.documents.reads, 0);
    });

    for (final (count, requests) in [(30, 1), (31, 2), (60, 2), (61, 3)]) {
      test('a teacher with $count groups sends $requests queries of 30 values '
          'at most', () async {
        world.act(
          'c1',
          Role.teacher,
          groups: [for (var i = 0; i < count - 1; i++) 'x$i', 'g2'],
        );

        expect([for (final s in await repository.all()) s.id.value], ['s2']);

        final sent = [
          for (final filter in world.documents.queryLog)
            (filter as FieldArrayContainsAny).values,
        ];
        expect(sent, hasLength(requests));
        expect(sent.every((values) => values.length <= 30), isTrue);
        expect(sent.expand((values) => values), hasLength(count));
        expect(sent.first, hasLength(count < 30 ? count : 30));
      });
    }

    test('a sheet found by two chunks appears once', () async {
      world.act(
        'c1',
        Role.teacher,
        groups: [for (var i = 0; i < 30; i++) 'x$i', 'g1', 'g2'],
      );
      world.documents.seed('clubs/c1/students/s9', {
        'firstName': 'Z',
        'audience': 'children',
        'groupIds': ['x0', 'g1'],
        'createdAt': DateTime(2026, 9, 2),
      });

      final ids = [for (final s in await repository.all()) s.id.value];

      expect(ids.where((id) => id == 's9'), hasLength(1));
      expect(world.documents.queryLog, hasLength(2));
    });

    test(
      'a parent or a student reads their linked sheets one by one',
      () async {
        world.act('c1', Role.guardian, students: ['s2', 's9', 's1']);

        expect(
          [for (final s in await repository.all()) s.id.value],
          ['s1', 's2'],
        );
        expect(world.documents.reads, 3);
      },
    );
  });

  test('a document of the wrong shape is a failure, not a guess', () async {
    world.documents.seed('clubs/c1/students/s1', {'firstName': 3});
    world.documents.seed('clubs/c1/students/s2', {
      'firstName': 'Léa',
      'audienceHistory': [
        {'audience': 'children', 'effectiveFrom': '2026-09-01'},
        {'audience': 'adults', 'effectiveFrom': '2026-01-01'},
      ],
    });
    world.documents.seed('clubs/c1/students/s3', {
      'firstName': 'Léa',
      'audience': 'seniors',
    });
    world.documents.seed('clubs/c1/students/s4', {
      'firstName': 'Léa',
      'audienceHistory': ['x'],
    });
    world.documents.seed('clubs/c1/students/s5', {
      'firstName': 'Léa',
      'audienceHistory': [
        {'audience': 'children', 'effectiveFrom': 42},
      ],
    });

    for (final id in ['s1', 's2', 's3', 's4', 's5']) {
      await expectLater(
        repository.byId(StudentId(id)),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.other,
          ),
        ),
        reason: id,
      );
    }
  });

  test('a published sheet with no audience at all opens as children', () async {
    world.documents.seed('clubs/c1/students/s1', {'firstName': 'Léa'});

    final student = (await repository.byId(const StudentId('s1')))!;

    expect(student.currentAudience, Audience.children);
  });

  test('without an active club nothing is read or written', () async {
    world.scope.deactivateClub();

    await expectLater(repository.all(), throwsA(isA<ServiceFailure>()));
    await expectLater(
      repository.create(_student('s1', 'Léa')),
      throwsA(isA<ServiceFailure>()),
    );
    expect(world.documents.reads + world.documents.commits, 0);
  });
}
