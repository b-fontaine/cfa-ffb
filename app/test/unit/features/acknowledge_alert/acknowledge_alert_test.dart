import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/features/acknowledge_alert/domain/acknowledge_alert.dart';
import 'package:billard_cfa/features/acknowledge_alert/domain/restore_alert.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

const _student = StudentId('s1');

void main() {
  late DomainWorld world;
  late AcknowledgeAlert acknowledge;
  late RestoreAlert restore;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1', 's2']);
    acknowledge = AcknowledgeAlert(
      world.students,
      world.attempts,
      world.acquisitions,
      world.acknowledgements,
      world.catalogueRepository,
      world.ids,
      InMemoryUnitOfWork(),
      world.config,
    );
    restore = RestoreAlert(world.acknowledgements, InMemoryUnitOfWork());
  });

  Future<void> misses(
    int count, {
    String student = 's1',
    int block = 1,
    int from = 1,
  }) async {
    for (var i = 0; i < count; i++) {
      await world.attempts.add(
        attempt(
          ref('a', block),
          potted: 0,
          student: student,
          dayOfMonth: from + i,
          id: 'f$student$block-${from + i}',
        ),
      );
    }
  }

  Future<StudentProgress> progressOf({String student = 's1'}) async =>
      StudentProgress.derive(
        studentId: StudentId(student),
        attempts: await world.attempts.forStudent(StudentId(student)),
        acquisitions: await world.acquisitions.forStudent(StudentId(student)),
        acknowledgements: await world.acknowledgements.forStudent(
          StudentId(student),
        ),
        rates: world.catalogue.rates,
        config: world.config,
      );

  Future<Result<AlertAcknowledgement>> see({
    String student = 's1',
    ExerciseRef? exercise,
    DateTime? today,
  }) => acknowledge(
    studentId: StudentId(student),
    exercise: exercise ?? ref('a', 1),
    today: today ?? DateTime(2026, 10, 12, 18, 30),
  );

  group('AcknowledgeAlert', () {
    test('links the acknowledgement to the last pass and to the day', () async {
      await misses(3);

      final seen = ok(await see());

      expect(seen.id.value, 'id-1');
      expect(seen.studentId, _student);
      expect(seen.exercise, ref('a', 1));
      expect(seen.lastAttemptId, const AttemptId('fs11-3'));
      expect(seen.date, DateTime(2026, 10, 12));
    });

    test('hides the alert without touching the passes', () async {
      await misses(3);

      ok(await see());

      final progress = await progressOf();
      expect(progress.activeAlerts, isEmpty);
      expect(progress.results[ref('a', 1)]!.consecutiveFailures, 3);
      expect(await world.attempts.forStudent(_student), hasLength(3));
    });

    test('accepts a persistent alert too', () async {
      await misses(5);

      expect(ok(await see()).exercise, ref('a', 1));
    });

    test('refuses an exercise without an active alert', () async {
      await misses(2);

      expect(codeOf(await see()), InvariantCode.alertNotActive);
      expect(await world.acknowledgements.all(), isEmpty);
    });

    test('refuses an exercise the student never practised', () async {
      expect(codeOf(await see()), InvariantCode.alertNotActive);
    });

    test('refuses an alert that is already acknowledged', () async {
      await misses(3);
      ok(await see());

      expect(codeOf(await see()), InvariantCode.alertNotActive);
      expect(await world.acknowledgements.all(), hasLength(1));
    });

    test('refuses the alert of an exercise acquired at placement', () async {
      await misses(3);
      await world.acquisitions.add(acquisition('a', day: 5));

      expect(codeOf(await see()), InvariantCode.alertNotActive);
    });

    test('refuses an unknown student', () async {
      expect(
        err(await see(student: 'ghost')),
        isA<NotFound>().having((e) => e.kind, 'kind', 'student'),
      );
    });

    test('refuses an unknown exercise', () async {
      expect(
        codeOf(await see(exercise: ref('zzz', 1))),
        InvariantCode.unknownExercise,
      );
      expect(
        codeOf(await see(exercise: ref('a', 9))),
        InvariantCode.unknownExercise,
      );
    });

    test(
      'a new failed pass brings the alert back and can be seen again',
      () async {
        await misses(3);
        ok(await see());
        await misses(1, from: 4);

        expect((await progressOf()).activeAlerts.single.consecutiveFailures, 4);

        final again = ok(await see(today: DateTime(2026, 10, 13)));

        expect(again.lastAttemptId, const AttemptId('fs11-4'));
        expect((await progressOf()).activeAlerts, isEmpty);
        expect(await world.acknowledgements.all(), hasLength(2));
      },
    );

    test('only the acknowledged student is concerned', () async {
      await misses(3);
      await misses(3, student: 's2');

      ok(await see());

      expect((await progressOf(student: 's2')).activeAlerts, hasLength(1));
    });
  });

  group('RestoreAlert', () {
    test('brings an acknowledged alert back', () async {
      await misses(3);
      ok(await see());

      ok(await restore(studentId: _student, exercise: ref('a', 1)));

      expect((await progressOf()).activeAlerts, hasLength(1));
      expect(await world.acknowledgements.all(), isEmpty);
    });

    test('can be acknowledged again after a restore', () async {
      await misses(3);
      ok(await see());
      ok(await restore(studentId: _student, exercise: ref('a', 1)));

      ok(await see());

      expect((await progressOf()).activeAlerts, isEmpty);
    });

    test(
      'removes every acknowledgement of that exercise, not the others',
      () async {
        await misses(3);
        ok(await see());
        await misses(1, from: 4);
        ok(await see());
        await misses(3, block: 2);
        ok(await see(exercise: ref('a', 2)));

        ok(await restore(studentId: _student, exercise: ref('a', 1)));

        final left = await world.acknowledgements.all();
        expect(left.map((a) => a.exercise), [ref('a', 2)]);
      },
    );

    test('refuses an exercise that has no acknowledgement', () async {
      expect(
        err(await restore(studentId: _student, exercise: ref('a', 1))),
        isA<NotFound>().having((e) => e.kind, 'kind', 'acknowledgement'),
      );
    });

    test('leaves the acknowledgements of another student alone', () async {
      await misses(3);
      await misses(3, student: 's2');
      ok(await see());
      ok(await see(student: 's2'));

      ok(await restore(studentId: _student, exercise: ref('a', 1)));

      expect((await world.acknowledgements.all()).map((a) => a.studentId), [
        const StudentId('s2'),
      ]);
    });
  });
}
