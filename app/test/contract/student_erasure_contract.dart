import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/club_seed.dart';
import 'repository_harness.dart';

/// Une réalisation du port `StudentErasure` et les dépôts sur lesquels elle
/// agit (de quoi semer et relire).
typedef ErasureSetup = ({
  StudentErasure erasure,
  RepositoryHarness repositories,
  Future<void> Function() close,
});

/// Le contrat de **l'effacement d'un élève** (FB8, ADR 0024 décision 19), joué
/// sur la même suite pour chaque réalisation : en mémoire, drift (une unité de
/// travail, `LocalStudentErasure`) et le faux Firestore (lots reprenables,
/// `ClubStudentErasure`). Ce que l'écran voit est le même partout : l'élève et
/// tout ce qui s'y rapporte disparaissent, les autres élèves ne changent pas,
/// un second effacement est « introuvable ». Les écarts propres à Firestore
/// (marqueur, lots, reprise) sont prouvés à part (`club_erasure.feature`,
/// `scripts/rules_test/operations.test.mjs`).
void studentErasureContract(
  String label,
  Future<ErasureSetup> Function() open,
) {
  group("$label : effacement d'un élève", () {
    late ErasureSetup setup;
    late SeededClub club;
    late String erased;
    late String kept;

    setUp(() async {
      setup = await open();
      final r = setup.repositories;
      club = await seedClub(
        const ClubSpec(groups: 1, studentsPerGroup: 3, attemptsPerStudent: 3),
        ClubSeedTarget(
          seasons: r.seasons,
          groups: r.groups,
          students: r.students,
          records: r.sessionRecords,
          attempts: r.attempts,
          assessments: r.assessments,
          acquisitions: r.acquisitions,
          acknowledgements: r.acknowledgements,
          planned: r.sessions,
        ),
      );
      erased = club.all.first;
      kept = club.all.last;
    });

    tearDown(() => setup.close());

    StudentId id(String name) => StudentId(SeededClub.idOf(name));

    Future<ErasureOutcome> erase(String name) async =>
        switch (await setup.erasure.erase(id(name))) {
          Ok(:final value) => value,
          Err(:final failure) => fail('effacement refusé : $failure'),
        };

    test(
      'inspect succeeds for a known student and says nothing is started',
      () async {
        final result = await setup.erasure.inspect(id(erased));

        final status = switch (result) {
          Ok(:final value) => value,
          Err(:final failure) => fail('$failure'),
        };
        expect(status.inProgress, isFalse);
      },
    );

    test('erasing completes and the student is gone', () async {
      final outcome = await erase(erased);

      expect(outcome.status, OperationRunStatus.completed);
      expect(await setup.repositories.students.byId(id(erased)), isNull);
      expect(await setup.repositories.students.byId(id(kept)), isNotNull);
    });

    test(
      'everything about the student is gone, nothing about the others',
      () async {
        await erase(erased);
        final r = setup.repositories;

        expect(await r.attempts.forStudent(id(erased)), isEmpty);
        expect(await r.assessments.forStudent(id(erased)), isEmpty);
        expect(await r.acquisitions.forStudent(id(erased)), isEmpty);
        expect(await r.acknowledgements.forStudent(id(erased)), isEmpty);
        expect(await r.attempts.forStudent(id(kept)), hasLength(3));
        expect(await r.assessments.forStudent(id(kept)), hasLength(1));
        expect(await r.acquisitions.forStudent(id(kept)), hasLength(1));
        expect(await r.acknowledgements.forStudent(id(kept)), hasLength(1));
      },
    );

    test(
      'the memberships and the attendance lists no longer name the student',
      () async {
        await erase(erased);
        final r = setup.repositories;

        for (final group in await r.groups.all()) {
          expect(
            group.memberships.map((m) => m.studentId),
            isNot(contains(id(erased))),
          );
          expect(group.memberships.map((m) => m.studentId), contains(id(kept)));
        }
        for (final record in await r.sessionRecords.all()) {
          expect(record.present, isNot(contains(id(erased))));
          expect(record.present, contains(id(kept)));
        }
      },
    );

    test('the sessions and the group stay, without the student', () async {
      await erase(erased);
      final r = setup.repositories;

      expect(await r.sessionRecords.all(), isNotEmpty);
      expect(await r.groups.all(), hasLength(1));
      expect(await r.seasons.all(), hasLength(1));
    });

    test('a second erasure of the same student is not found', () async {
      await erase(erased);

      final again = await setup.erasure.erase(id(erased));
      final inspected = await setup.erasure.inspect(id(erased));

      expect((again as Err<Object?>).failure, isA<NotFound>());
      expect((inspected as Err<Object?>).failure, isA<NotFound>());
    });

    test('an unknown student is not found', () async {
      final result = await setup.erasure.erase(const StudentId('inconnu'));

      expect((result as Err<Object?>).failure, isA<NotFound>());
    });

    test('erasing every student one by one leaves no student', () async {
      for (final name in club.all) {
        await erase(name);
      }
      final r = setup.repositories;

      expect(await r.students.all(), isEmpty);
      expect(await r.attempts.all(), isEmpty);
      expect(await r.assessments.all(), isEmpty);
    });
  });
}
