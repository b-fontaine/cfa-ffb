import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/features/track_progress/domain/attendance.dart';
import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/features/track_progress/domain/get_student_sheet.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late GetStudentSheet sheet;
  const student = StudentId('s1');

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    await world.session(dayOfMonth: 2, main: 'a');
    sheet = GetStudentSheet(
      world.students,
      world.attempts,
      world.sessions,
      world.groups,
      world.assessments,
      world.catalogueRepository,
      world.config,
    );
  });

  Future<void> pass(
    ExerciseRef exercise,
    int potted, {
    required String id,
    int dayOfMonth = 2,
    int passIndex = 1,
  }) => world.attempts.add(
    attempt(
      exercise,
      potted: potted,
      id: id,
      dayOfMonth: dayOfMonth,
      passIndex: passIndex,
    ),
  );

  test(
    'presents a new student at the first exercise of the first block',
    () async {
      final result = ok(await sheet(student));

      expect(result.student.firstName, 's1');
      expect(result.nextExercise, ref('a', 1));
      expect(result.passesRequired, 5);
      expect(result.report.validatedCount, 0);
      expect(result.report.blocks.map((b) => b.blockId), ['a', 'b', 'c']);
      expect(result.series, isEmpty);
      expect(result.latestAssessment, isNull);
      expect(result.readinessHint, isNull);
      expect(result.catalogue, world.catalogue);
    },
  );

  test('builds the curve of each practised exercise', () async {
    await pass(ref('a', 1), 4, id: 'p1');
    await pass(ref('a', 1), 1, id: 'p2', passIndex: 2);
    await pass(ref('b', 2), 5, id: 'p3', dayOfMonth: 3);

    final result = ok(await sheet(student));

    expect(result.series.map((s) => s.exercise), [ref('a', 1), ref('b', 2)]);
    final first = result.series.first;
    expect(first.rate, rate());
    expect(first.status, ExerciseStatus.inProgress);
    expect(first.passedCount, 1);
    expect(first.curve.points.map((p) => p.potted), [4, 1]);
    expect(first.alert, AlertLevel.none);
  });

  test('moves the next exercise on after a validation', () async {
    for (var i = 0; i < 5; i++) {
      await pass(ref('a', 1), 4, id: 'v$i', dayOfMonth: 2 + i);
    }

    final result = ok(await sheet(student));

    expect(result.nextExercise, ref('a', 2));
    expect(result.report.validatedCount, 1);
    expect(result.series.single.status, ExerciseStatus.validated);
    expect(result.report.blocks.first.status, BlockStatus.inProgress);
  });

  test('carries the alert of consecutive failures', () async {
    for (var i = 0; i < 3; i++) {
      await pass(ref('a', 1), 0, id: 'f$i', dayOfMonth: 2 + i);
    }

    final result = ok(await sheet(student));

    expect(result.series.single.alert, AlertLevel.attention);
    expect(result.series.single.consecutiveFailures, 3);
    expect(result.report.activeAlerts, hasLength(1));
  });

  test('gives the latest assessment with the readiness hint', () async {
    await world.assessments.add(
      MaturityAssessment(
        id: const AssessmentId('m1'),
        studentId: student,
        date: day(3),
        concentration: 4,
        endurance: 4,
        frustration: 4,
      ),
    );
    await world.assessments.add(
      MaturityAssessment(
        id: const AssessmentId('m2'),
        studentId: student,
        date: day(9),
        concentration: 2,
        endurance: 4,
        frustration: 4,
        comment: 'Fatigué',
      ),
    );

    final result = ok(await sheet(student));

    expect(result.latestAssessment!.id, const AssessmentId('m2'));
    expect(result.latestAssessment!.comment, 'Fatigué');
    expect(result.readinessHint, isFalse);
    expect(result.assessmentCount, 2);
  });

  test('has no next exercise once the level is completed', () async {
    for (final spec in world.catalogue.exercises) {
      for (var i = 0; i < 5; i++) {
        await pass(spec.ref, 4, id: '${spec.ref.blockId}${spec.ref.number}$i');
      }
    }

    final result = ok(await sheet(student));

    expect(result.nextExercise, isNull);
    expect(result.report.validatedCount, 9);
  });

  test('reports the attendance over the sessions of the group', () async {
    await world.session(id: 'x2', dayOfMonth: 4, present: const {});
    await world.session(id: 'x3', dayOfMonth: 6);

    final result = ok(await sheet(student));

    expect(result.report.attendance, const Attendance(attended: 2, total: 3));
  });

  test('refuses an unknown student', () async {
    final result = await sheet(const StudentId('nope'));

    expect(err(result), isA<NotFound>());
  });
}
