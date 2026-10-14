import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/features/track_progress/domain/get_exercise_curve.dart';
import 'package:billard_cfa/features/track_progress/domain/get_student_report.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

const _student = StudentId('s1');

void main() {
  late DomainWorld world;
  late GetExerciseCurve getCurve;
  late GetStudentReport getReport;
  var counter = 0;

  Future<void> record(
    String block,
    int number,
    int potted, {
    int dayOfMonth = 1,
    String session = 'x1',
    String student = 's1',
  }) => world.attempts.add(
    attempt(
      ref(block, number),
      potted: potted,
      dayOfMonth: dayOfMonth,
      session: session,
      student: student,
      id: 'p${counter++}',
    ),
  );

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1', 's2']);
    getCurve = GetExerciseCurve(
      world.attempts,
      world.catalogueRepository,
      world.config,
    );
    getReport = GetStudentReport(
      world.attempts,
      world.sessions,
      world.groups,
      world.catalogueRepository,
      world.config,
    );
  });

  group('GetExerciseCurve', () {
    test('returns the curve of the requested exercise only', () async {
      await record('a', 1, 3);
      await record('a', 1, 4, dayOfMonth: 2);
      await record('a', 2, 5, dayOfMonth: 3);
      await record('a', 1, 5, dayOfMonth: 4, student: 's2');

      final curve = ok(
        await getCurve(studentId: _student, exercise: ref('a', 1)),
      );

      expect(curve.points.map((p) => p.potted), [3, 4]);
    });

    test('returns an empty curve for an exercise never practised', () async {
      final curve = ok(
        await getCurve(studentId: _student, exercise: ref('b', 3)),
      );

      expect(curve.points, isEmpty);
    });

    test('refuses an exercise outside the catalogue', () async {
      final result = await getCurve(studentId: _student, exercise: ref('a', 9));

      expect(codeOf(result), InvariantCode.unknownExercise);
    });
  });

  group('GetStudentReport', () {
    test('reports every block as not started for a new student', () async {
      final report = ok(await getReport(_student));

      expect(report.studentId, _student);
      expect(report.exerciseCount, 9);
      expect(report.validatedCount, 0);
      expect(report.blocks.map((b) => b.blockId), ['a', 'b', 'c']);
      expect(
        report.blocks.every((b) => b.status == BlockStatus.notStarted),
        isTrue,
      );
      expect(report.activeAlerts, isEmpty);
    });

    test('counts validated exercises and lists active alerts', () async {
      for (var d = 1; d <= 3; d++) {
        await record('a', 1, 3, dayOfMonth: d, session: 's$d');
        await record('a', 1, 3, dayOfMonth: d, session: 's$d');
      }
      for (var d = 4; d <= 6; d++) {
        await record('b', 2, 0, dayOfMonth: d, session: 's$d');
      }

      final report = ok(await getReport(_student));

      expect(report.validatedCount, 1);
      expect(report.blocks[0].status, BlockStatus.inProgress);
      expect(report.blocks[0].validatedCount, 1);
      expect(report.blocks[1].status, BlockStatus.toReview);
      expect(report.activeAlerts.single.exercise, ref('b', 2));
      expect(report.activeAlerts.single.alert, AlertLevel.attention);
    });

    test(
      'counts the sessions spent on a block from the session list',
      () async {
        await world.session(main: 'a');
        await world.session(id: 'x2', dayOfMonth: 2, main: 'a');
        await world.session(id: 'x3', dayOfMonth: 3, main: 'a');
        await world.session(id: 'x4', dayOfMonth: 4, main: 'b');

        final report = ok(await getReport(_student));

        expect(report.blocks[0].sessionsSpent, 3);
        expect(report.blocks[0].overdue, isTrue);
        expect(report.blocks[1].sessionsSpent, 1);
        expect(report.blocks[2].sessionsSpent, 0);
      },
    );
  });
}
