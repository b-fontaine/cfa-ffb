import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/exercise_result/domain/watch_list.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

void main() {
  final a1 = ref('a', 1);
  final a2 = ref('a', 2);
  final b1 = ref('b', 1);
  final order = [a1, a2, ref('a', 3), b1];
  final config = RulesConfig();
  var ids = 0;

  /// [count] échecs (2 billes sur 5, taux requis 3/5) de [student].
  List<ExerciseAttempt> failures(
    String student,
    ExerciseRef exercise,
    int count,
  ) => [
    for (var i = 0; i < count; i++)
      attempt(
        exercise,
        potted: 2,
        student: student,
        dayOfMonth: 1 + i,
        id: 'f${ids++}',
      ),
  ];

  StudentProgress progressOf(
    String student,
    List<ExerciseAttempt> attempts, {
    List<BlockAcquisitionFixture> acquired = const [],
  }) => StudentProgress.derive(
    studentId: StudentId(student),
    attempts: attempts,
    acquisitions: [
      for (final block in acquired)
        acquisition(block.blockId, day: block.day, student: student),
    ],
    rates: buildCatalogue().rates,
    config: config,
  );

  test('lists nobody when no alert is active', () {
    final progress = progressOf('s1', failures('s1', a1, 2));

    expect(watchedStudents([progress], catalogueOrder: order), isEmpty);
  });

  test('keeps one line per student with the most alarming exercise', () {
    final progress = progressOf('s1', [
      ...failures('s1', a1, 3),
      ...failures('s1', a2, 4),
    ]);

    final watched = watchedStudents([progress], catalogueOrder: order).single;

    expect(watched.exercise, a2);
    expect(watched.consecutiveFailures, 4);
    expect(watched.alert, AlertLevel.attention);
    expect(watched.otherAlerts, 1);
  });

  test('the persistent alert is the most alarming', () {
    final config = RulesConfig(persistentAlertThreshold: 4);
    final progress = StudentProgress.derive(
      studentId: const StudentId('s1'),
      attempts: [...failures('s1', a1, 4), ...failures('s1', a2, 3)],
      acquisitions: const [],
      rates: buildCatalogue().rates,
      config: config,
    );

    final watched = watchedStudents([progress], catalogueOrder: order).single;

    expect(watched.exercise, a1);
    expect(watched.alert, AlertLevel.persistent);
  });

  test('breaks a tie by the teaching order of the exercises', () {
    final progress = progressOf('s1', [
      ...failures('s1', b1, 3),
      ...failures('s1', a2, 3),
    ]);

    final watched = watchedStudents([progress], catalogueOrder: order).single;

    expect(watched.exercise, a2);
  });

  test('orders persistent first, then failures, then student id', () {
    final list = watchedStudents([
      progressOf('s3', failures('s3', a1, 3)),
      progressOf('s2', failures('s2', a1, 4)),
      progressOf('s1', failures('s1', a1, 3)),
      progressOf('s4', failures('s4', a1, 5)),
    ], catalogueOrder: order);

    expect([for (final w in list) w.studentId.value], ['s4', 's2', 's1', 's3']);
  });

  test('compareWatched ranks level, then failures, then student id', () {
    WatchedStudent watched(String id, AlertLevel alert, int failures) =>
        WatchedStudent(
          studentId: StudentId(id),
          exercise: a1,
          alert: alert,
          consecutiveFailures: failures,
          otherAlerts: 0,
        );
    final persistent = watched('s9', AlertLevel.persistent, 5);
    final moreFailures = watched('s8', AlertLevel.attention, 4);
    final tieB = watched('B', AlertLevel.attention, 3);
    final tieA = watched('a', AlertLevel.attention, 3);

    expect(compareWatched(persistent, moreFailures), isNegative);
    expect(compareWatched(moreFailures, tieB), isNegative);
    expect(compareWatched(tieB, tieA), isNegative);
    expect(compareWatched(tieA, tieB), isPositive);
    expect(compareWatched(tieA, tieA), isZero);
  });

  test('hides the alert of an exercise still acquired at placement', () {
    final progress = progressOf(
      's1',
      failures('s1', a1, 3),
      acquired: [const BlockAcquisitionFixture('a', 20)],
    );

    expect(watchedStudents([progress], catalogueOrder: order), isEmpty);
  });
}

class BlockAcquisitionFixture {
  const BlockAcquisitionFixture(this.blockId, this.day);

  final String blockId;
  final int day;
}
