import 'package:billard_cfa/entities/student/data/store_student_directory.dart';
import 'package:billard_cfa/entities/student/domain/student_directory.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryDocumentStore store;
  late StoreStudentDirectory directory;
  final now = DateTime(2026, 10, 12, 9, 30);
  const club = ClubId('c1');

  PublishedStudent student(
    String id,
    String name, {
    Audience audience = Audience.children,
    List<String> groups = const ['g1'],
  }) => PublishedStudent(
    id: StudentId(id),
    firstName: name,
    audience: audience,
    groupIds: [for (final g in groups) GroupId(g)],
  );

  setUp(() {
    store = InMemoryDocumentStore()..serverNow = () => now;
    directory = StoreStudentDirectory(store);
  });

  test(
    'publishes the minimal fiche: first name, audience, groups, date',
    () async {
      await directory.publish(club, [
        student('s1', 'Léa'),
        student('s2', 'Marc', audience: Audience.adults, groups: ['g1', 'g2']),
      ]);

      expect(store.read('clubs/c1/students/s1'), {
        'firstName': 'Léa',
        'audience': 'children',
        'groupIds': ['g1'],
        'createdAt': now,
      });
      expect(store.read('clubs/c1/students/s2'), {
        'firstName': 'Marc',
        'audience': 'adults',
        'groupIds': ['g1', 'g2'],
        'createdAt': now,
      });
    },
  );

  test('does not rewrite a fiche that already exists', () async {
    store.seed('clubs/c1/students/s1', {
      'firstName': 'Déjà',
      'groupIds': ['g9'],
    });

    await directory.publish(club, [student('s1', 'Léa'), student('s2', 'Tom')]);

    expect(store.read('clubs/c1/students/s1'), {
      'firstName': 'Déjà',
      'groupIds': ['g9'],
    });
    expect(store.read('clubs/c1/students/s2'), isNotNull);
  });

  test('writes all the missing fiches in one batch', () async {
    await directory.publish(club, [student('s1', 'Léa'), student('s2', 'Tom')]);
    expect(store.commits, 1);
  });

  test('nothing to publish writes nothing', () async {
    await directory.publish(club, []);
    store.seed('clubs/c1/students/s1', {
      'firstName': 'A',
      'groupIds': <String>[],
    });
    final commits = store.commits;
    await directory.publish(club, [student('s1', 'A')]);
    expect(store.commits, commits);
  });

  test('trims the first name and cuts it at the server limit', () async {
    await directory.publish(club, [
      student('s1', '  Léa '),
      student('s2', 'é' * (maxFirstNameLength + 10)),
    ]);

    expect(store.read('clubs/c1/students/s1')!['firstName'], 'Léa');
    expect(
      store.read('clubs/c1/students/s2')!['firstName'],
      'é' * maxFirstNameLength,
    );
  });

  test('keeps clubs apart', () async {
    await directory.publish(club, [student('s1', 'Léa')]);
    expect(store.read('clubs/c2/students/s1'), isNull);
  });

  test(
    'a service failure becomes a ServiceFailure and writes nothing',
    () async {
      store.failing = StoreFailureCode.unavailable;
      await expectLater(
        directory.publish(club, [student('s1', 'Léa')]),
        throwsA(isA<Exception>()),
      );
      store.failing = null;
      expect(store.read('clubs/c1/students/s1'), isNull);
    },
  );
}
