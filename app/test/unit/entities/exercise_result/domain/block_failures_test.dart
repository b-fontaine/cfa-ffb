import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_failures.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

final TrainingBlock _block = block('a', 1);
int _ids = 0;

ExerciseAttempt pass(
  String student,
  int number, {
  required bool passed,
  required int dayOfMonth,
}) => attempt(
  ref('a', number),
  potted: passed ? 3 : 2,
  student: student,
  dayOfMonth: dayOfMonth,
  id: 'p${_ids++}',
);

Map<StudentId, StudentProgress> progressOf(
  Map<String, List<ExerciseAttempt>> byStudent, {
  List<BlockAcquisition> acquisitions = const [],
}) => {
  for (final entry in byStudent.entries)
    StudentId(entry.key): StudentProgress.derive(
      studentId: StudentId(entry.key),
      attempts: entry.value,
      acquisitions: acquisitions,
      rates: buildCatalogue().rates,
      config: RulesConfig(passesRequired: 1),
    ),
};

void main() {
  test('lists the students whose last pass on the block failed', () {
    final failed = blockFailedStudents(
      exercises: _block.exerciseRefs,
      progress: progressOf({
        's1': [pass('s1', 1, passed: false, dayOfMonth: 3)],
        's2': [pass('s2', 1, passed: true, dayOfMonth: 3)],
        's3': [],
      }),
    );

    expect(failed.keys, [const StudentId('s1')]);
  });

  test('gives the date of the failed last pass', () {
    final failed = blockFailedStudents(
      exercises: _block.exerciseRefs,
      progress: progressOf({
        's1': [pass('s1', 1, passed: false, dayOfMonth: 3)],
      }),
    );

    expect(failed[const StudentId('s1')], day(3));
  });

  test('the last pass of the block is the latest across its exercises', () {
    final failed = blockFailedStudents(
      exercises: _block.exerciseRefs,
      progress: progressOf({
        // Échec sur 1 puis réussite sur 2 : le dernier passage a réussi.
        's1': [
          pass('s1', 1, passed: false, dayOfMonth: 1),
          pass('s1', 2, passed: true, dayOfMonth: 2),
        ],
        // Réussite sur 1 puis échec sur 2 : le dernier passage a échoué.
        's2': [
          pass('s2', 1, passed: true, dayOfMonth: 1),
          pass('s2', 2, passed: false, dayOfMonth: 2),
        ],
      }),
    );

    expect(failed.keys, [const StudentId('s2')]);
  });

  test('an exercise acquired at placement is not counted', () {
    final failed = blockFailedStudents(
      exercises: _block.exerciseRefs,
      progress: progressOf(
        {
          's1': [pass('s1', 1, passed: false, dayOfMonth: 1)],
        },
        acquisitions: [acquisition('a', day: 5)],
      ),
    );

    expect(failed, isEmpty);
  });

  test('latestBlockResult is null for a student who never practised', () {
    final progress = progressOf({'s1': []});

    expect(
      latestBlockResult(_block.exerciseRefs, progress.values.single),
      isNull,
    );
  });

  test('latestBlockResult is the result with the most recent last pass', () {
    final progress = progressOf({
      's1': [
        pass('s1', 1, passed: true, dayOfMonth: 1),
        pass('s1', 3, passed: false, dayOfMonth: 4),
        pass('s1', 2, passed: true, dayOfMonth: 2),
      ],
    });

    expect(
      latestBlockResult(_block.exerciseRefs, progress.values.single)!.exercise,
      ref('a', 3),
    );
  });

  group('reachesGroupFailureShare', () {
    test('is reached when the share equals the threshold', () {
      expect(
        reachesGroupFailureShare(failed: 4, members: 8, sharePercent: 50),
        isTrue,
      );
    });

    test('is not reached just below the threshold', () {
      expect(
        reachesGroupFailureShare(failed: 3, members: 8, sharePercent: 50),
        isFalse,
      );
    });

    test('compares without rounding the share', () {
      expect(
        reachesGroupFailureShare(failed: 2, members: 3, sharePercent: 66),
        isTrue,
      );
      expect(
        reachesGroupFailureShare(failed: 2, members: 3, sharePercent: 67),
        isFalse,
      );
    });

    test(
      'reaches the share for an empty group (callers guard with a minimum)',
      () {
        expect(
          reachesGroupFailureShare(failed: 0, members: 0, sharePercent: 50),
          isTrue,
        );
      },
    );
  });
}
