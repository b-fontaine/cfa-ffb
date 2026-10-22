import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un club Firestore ouvert (directeur de `c1`) et son unité de travail.
typedef UnitOfWorkSetup = ({
  ClubStore club,
  UnitOfWork unitOfWork,
  Future<void> Function() close,
});

Student _student(String id) => Student.enroll(
  id: StudentId(id),
  firstName: 'Léa',
  audience: Audience.children,
  since: DateTime(2026, 9),
);

Group _groupWith(String id, List<String> students) {
  var group = Group(
    id: GroupId(id),
    seasonId: const SeasonId('season'),
    name: 'Jeunes',
    audience: Audience.children,
  );
  for (final student in students) {
    group = group.admit(
      studentId: StudentId(student),
      studentAudience: Audience.children,
      from: DateTime(2026, 9),
    );
  }
  return group;
}

/// Atomicité de l'`UnitOfWork` Firestore (ADR 0024, décision 19 : un
/// `WriteBatch` pour les petits cas), jouée sur le double en mémoire et sur le
/// faux Firestore : tout ou rien, lecture de ses propres écritures, limite de
/// 500 écritures annoncée par une erreur explicite.
///
/// [storeRollsBack] : le stock annule lui-même un lot dont une écriture est
/// refusée. Vrai pour le double ; **faux pour `fake_cloud_firestore`**, qui
/// applique les écritures une à une (mesuré) : l'atomicité du vrai lot est
/// prouvée contre l'émulateur (`scripts/rules_test/repositories.test.mjs`).
void unitOfWorkContract(
  String label,
  Future<UnitOfWorkSetup> Function() open, {
  bool storeRollsBack = true,
}) {
  group('$label : unité de travail Firestore', () {
    late UnitOfWorkSetup setup;
    late FirestoreStudentRepository students;
    late FirestoreGroupRepository groups;

    setUp(() async {
      setup = await open();
      students = FirestoreStudentRepository(setup.club);
      groups = FirestoreGroupRepository(setup.club);
    });
    tearDown(() => setup.close());

    test('applies every write of the body together', () async {
      await setup.unitOfWork.run(() async {
        await students.create(_student('s1'));
        await groups.save(_groupWith('g1', ['s1']));
      });

      expect(await students.byId(const StudentId('s1')), isNotNull);
      expect(
        (await groups.byId(const GroupId('g1')))!.memberships,
        hasLength(1),
      );
    });

    test('a student created in the unit sees its group (own writes)', () async {
      // Sans lecture de ses propres écritures, `groups.save` ne voyait pas la
      // fiche encore absente et laissait `groupIds` vide.
      await setup.unitOfWork.run(() async {
        await students.create(_student('s1'));
        await groups.save(_groupWith('g1', ['s1']));
      });

      final stored = await setup.club.documents.get('clubs/c1/students/s1');
      expect(stored!.fields['groupIds'], ['g1']);
    });

    test('writes nothing when the body fails', () async {
      await expectLater(
        setup.unitOfWork.run<void>(() async {
          await students.create(_student('s1'));
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(await students.byId(const StudentId('s1')), isNull);
    });

    if (storeRollsBack) {
      test('writes nothing when one write is refused by the store', () async {
        await expectLater(
          setup.unitOfWork.run<void>(() async {
            await setup.club.commit([
              const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
              // Mise à jour d'un document absent : le lot entier échoue.
              const UpdateOp('clubs/c1/students/absent', {'firstName': 'x'}),
            ]);
          }),
          throwsA(
            isA<ServiceFailure>().having(
              (f) => f.code,
              'code',
              ServiceFailureCode.other,
            ),
          ),
        );

        expect(await setup.club.documents.get('clubs/c1/students/s1'), isNull);
      });
    }

    test('refuses more than 500 writes with an explicit error', () async {
      await expectLater(
        setup.unitOfWork.run<void>(
          () => setup.club.commit([
            for (var i = 0; i < 501; i++)
              SetOp('clubs/c1/students/s$i', {'firstName': 'Léa'}),
          ]),
        ),
        throwsA(
          isA<ServiceFailure>()
              .having((f) => f.code, 'code', ServiceFailureCode.other)
              .having((f) => f.detail, 'detail', contains('501')),
        ),
      );

      expect(await setup.club.documents.list('clubs/c1/students'), isEmpty);
    });

    test('accepts exactly 500 writes in one batch', () async {
      await setup.unitOfWork.run(
        () => setup.club.commit([
          for (var i = 0; i < 500; i++)
            SetOp('clubs/c1/students/s$i', {'firstName': 'Léa'}),
        ]),
      );

      expect(
        await setup.club.documents.list('clubs/c1/students'),
        hasLength(500),
      );
    });

    test('a nested unit joins the outer one: all or nothing', () async {
      await expectLater(
        setup.unitOfWork.run<void>(() async {
          await setup.unitOfWork.run(() => students.create(_student('s1')));
          throw StateError('outer fails');
        }),
        throwsStateError,
      );

      expect(await students.byId(const StudentId('s1')), isNull);
    });
  });
}
