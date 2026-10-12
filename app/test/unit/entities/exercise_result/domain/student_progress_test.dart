import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

const _student = StudentId('s1');

StudentProgress derive(List<ExerciseAttempt> attempts) =>
    StudentProgress.derive(
      studentId: _student,
      attempts: attempts,
      rates: buildCatalogue().rates,
      config: RulesConfig(passesRequired: 2),
    );

void main() {
  test('has no result without attempts', () {
    final progress = derive([]);

    expect(progress.results, isEmpty);
    expect(progress.validated, isEmpty);
    expect(progress.activeAlerts, isEmpty);
  });

  test('groups attempts by exercise', () {
    final progress = derive([
      attempt(ref('a', 1), potted: 3, id: '1'),
      attempt(ref('a', 1), potted: 3, dayOfMonth: 2, id: '2'),
      attempt(ref('b', 2), potted: 1, id: '3'),
    ]);

    expect(progress.results.keys, {ref('a', 1), ref('b', 2)});
    expect(progress.results[ref('a', 1)]!.passedCount, 2);
    expect(progress.results[ref('b', 2)]!.status, ExerciseStatus.inProgress);
  });

  test('lists validated exercises', () {
    final progress = derive([
      attempt(ref('a', 1), potted: 3, id: '1'),
      attempt(ref('a', 1), potted: 3, dayOfMonth: 2, id: '2'),
      attempt(ref('a', 2), potted: 3, id: '3'),
    ]);

    expect(progress.validated, {ref('a', 1)});
  });

  test('lists active alerts only', () {
    final progress = derive([
      for (var i = 0; i < 3; i++)
        attempt(ref('a', 1), potted: 0, dayOfMonth: i + 1, id: 'f$i'),
      attempt(ref('a', 2), potted: 0, id: 'g'),
    ]);

    expect(progress.activeAlerts.map((r) => r.exercise), [ref('a', 1)]);
  });

  test('ignores attempts of other students', () {
    final progress = derive([
      attempt(ref('a', 1), potted: 3, student: 'other', id: '1'),
    ]);

    expect(progress.results, isEmpty);
  });

  test('refuses an attempt on an exercise unknown to the catalogue', () {
    expect(
      () => derive([attempt(ref('zzz', 1), potted: 3)]),
      violation(InvariantCode.unknownExercise),
    );
  });
}
