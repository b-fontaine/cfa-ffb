import 'package:billard_cfa/entities/student/data/existing_student_directory.dart';
import 'package:billard_cfa/entities/student/domain/student_directory.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sous Firestore, les fiches existent déjà : l'annuaire ne fait que vérifier
/// leur présence et ne crée JAMAIS de fiche (une fiche effacée par un autre
/// appareil ne doit pas revenir entre la liste et la publication).
void main() {
  const club = ClubId('c1');
  late InMemoryDocumentStore store;
  late ExistingStudentDirectory directory;

  const lea = PublishedStudent(
    id: StudentId('s1'),
    firstName: 'Léa',
    audience: Audience.children,
    groupIds: [GroupId('g1')],
  );

  setUp(() {
    store = InMemoryDocumentStore();
    directory = ExistingStudentDirectory(store);
  });

  test('a fiche that exists is left untouched', () async {
    store.seed('clubs/c1/students/s1', {
      'firstName': 'Déjà',
      'groupIds': ['g9'],
    });
    await directory.publish(club, [lea]);
    expect(store.read('clubs/c1/students/s1'), {
      'firstName': 'Déjà',
      'groupIds': ['g9'],
    });
    expect(store.commits, 0);
  });

  test(
    'a fiche erased between the list and publish is not recreated',
    () async {
      await expectLater(
        directory.publish(club, [lea]),
        throwsA(
          isA<InvariantViolation>().having(
            (e) => e.code,
            'code',
            InvariantCode.actionNotAllowed,
          ),
        ),
      );
      expect(store.read('clubs/c1/students/s1'), isNull);
      expect(store.commits, 0);
    },
  );
}
