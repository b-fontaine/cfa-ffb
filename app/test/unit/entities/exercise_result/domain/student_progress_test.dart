import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

const _student = StudentId('s1');

StudentProgress derive(
  List<ExerciseAttempt> attempts, {
  List<BlockAcquisition> acquisitions = const [],
  List<AlertAcknowledgement> acknowledgements = const [],
}) => StudentProgress.derive(
  studentId: _student,
  attempts: attempts,
  acquisitions: acquisitions,
  acknowledgements: acknowledgements,
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

  group('blocks acquired at placement', () {
    test('counts every exercise of the block as validated, with no result', () {
      final progress = derive([], acquisitions: [acquisition('a', day: 5)]);

      expect(progress.validated, {ref('a', 1), ref('a', 2), ref('a', 3)});
      expect(progress.acquiredExercises, progress.validated);
      expect(progress.results, isEmpty);
      expect(progress.resumedExercises, isEmpty);
      expect(progress.acquiredBlocks.keys, ['a']);
      expect(progress.isAcquired('a'), isTrue);
      expect(progress.acquiredOn('a'), day(5));
      expect(progress.isAcquired('b'), isFalse);
      expect(progress.acquiredOn('b'), isNull);
    });

    test('unions acquired exercises with those validated by passes', () {
      final progress = derive(
        [
          attempt(ref('b', 1), potted: 3, id: '1'),
          attempt(ref('b', 1), potted: 3, dayOfMonth: 2, id: '2'),
        ],
        acquisitions: [acquisition('a', day: 5)],
      );

      expect(progress.validated, {
        ref('a', 1),
        ref('a', 2),
        ref('a', 3),
        ref('b', 1),
      });
    });

    test('ignores markers of other students and of unknown blocks', () {
      final progress = derive(
        [],
        acquisitions: [
          acquisition('a', student: 'other'),
          acquisition('zzz', id: 'q2'),
        ],
      );

      expect(progress.acquiredBlocks, isEmpty);
      expect(progress.validated, isEmpty);
    });

    test('a pass on the day of the placement takes over its exercise only', () {
      final progress = derive(
        [attempt(ref('a', 1), potted: 3, dayOfMonth: 5, id: '1')],
        acquisitions: [acquisition('a', day: 5)],
      );

      expect(progress.resumedExercises, {ref('a', 1)});
      expect(progress.acquiredExercises, {ref('a', 2), ref('a', 3)});
      expect(progress.validated, {ref('a', 2), ref('a', 3)});
      expect(progress.isAcquired('a'), isFalse);
      expect(progress.resumedCount('a'), 1);
      expect(progress.acquiredOn('a'), day(5));
    });

    test('a pass after the placement takes over its exercise', () {
      final progress = derive(
        [attempt(ref('a', 2), potted: 3, dayOfMonth: 9, id: '1')],
        acquisitions: [acquisition('a', day: 5)],
      );

      expect(progress.resumedExercises, {ref('a', 2)});
    });

    test('a pass dated before the placement does not take over', () {
      final progress = derive(
        [attempt(ref('a', 1), potted: 3, dayOfMonth: 4, id: '1')],
        acquisitions: [acquisition('a', day: 5)],
      );

      expect(progress.resumedExercises, isEmpty);
      expect(progress.isAcquired('a'), isTrue);
      expect(progress.results.keys, [ref('a', 1)]);
    });

    test('a marker whose exercises are all taken over stays readable', () {
      final progress = derive(
        [
          for (var n = 1; n <= 3; n++)
            attempt(ref('a', n), potted: 3, dayOfMonth: 6, id: 'p$n'),
        ],
        acquisitions: [acquisition('a', day: 5)],
      );

      expect(progress.acquiredExercises, isEmpty);
      expect(progress.resumedCount('a'), 3);
      expect(progress.isAcquired('a'), isFalse);
      expect(progress.acquiredOn('a'), day(5));
      expect(progress.validated, isEmpty);
    });

    test('the most recent marker of a block wins', () {
      final progress = derive(
        [attempt(ref('a', 1), potted: 3, dayOfMonth: 5, id: '1')],
        acquisitions: [
          acquisition('a', day: 7, id: 'q2'),
          acquisition('a', day: 3),
        ],
      );

      expect(progress.acquiredOn('a'), day(7));
      expect(progress.resumedExercises, isEmpty);
    });

    test('hides the alert of an acquired exercise until it is taken over', () {
      final failures = [
        for (var i = 1; i <= 3; i++)
          attempt(ref('a', 1), potted: 0, dayOfMonth: i, id: 'f$i'),
      ];
      final acquisitions = [acquisition('a', day: 5)];

      expect(
        derive(failures, acquisitions: acquisitions).activeAlerts,
        isEmpty,
      );

      final taken = derive([
        ...failures,
        attempt(ref('a', 1), potted: 0, dayOfMonth: 5, id: 'f4'),
      ], acquisitions: acquisitions);
      expect(taken.activeAlerts.map((r) => r.exercise), [ref('a', 1)]);
    });
  });

  group('alert acknowledgements', () {
    ExerciseAttempt miss(int dayOfMonth) => attempt(
      ref('a', 1),
      potted: 0,
      dayOfMonth: dayOfMonth,
      id: 'f$dayOfMonth',
    );

    final three = [miss(1), miss(2), miss(3)];

    test('an acknowledged alert is no longer active', () {
      final progress = derive(
        three,
        acknowledgements: [acknowledgement(ref('a', 1), lastAttempt: 'f3')],
      );

      expect(progress.activeAlerts, isEmpty);
      expect(progress.acknowledgedAlerts.keys, [ref('a', 1)]);
      expect(progress.acknowledgedAlertResults.map((r) => r.exercise), [
        ref('a', 1),
      ]);
    });

    test('the result itself keeps its alert level and failures', () {
      final progress = derive(
        three,
        acknowledgements: [acknowledgement(ref('a', 1), lastAttempt: 'f3')],
      );

      final result = progress.results[ref('a', 1)]!;
      expect(result.alert, AlertLevel.attention);
      expect(result.consecutiveFailures, 3);
    });

    test('a new failed pass brings the alert back with the new count', () {
      final progress = derive(
        [...three, miss(4)],
        acknowledgements: [acknowledgement(ref('a', 1), lastAttempt: 'f3')],
      );

      expect(progress.activeAlerts.single.consecutiveFailures, 4);
      expect(progress.acknowledgedAlerts, isEmpty);
    });

    test('a passed pass resolves the alert and the acknowledgement sleeps', () {
      final progress = derive(
        [...three, attempt(ref('a', 1), potted: 3, dayOfMonth: 4, id: 'p4')],
        acknowledgements: [acknowledgement(ref('a', 1), lastAttempt: 'f3')],
      );

      expect(progress.activeAlerts, isEmpty);
      expect(progress.acknowledgedAlerts, isEmpty);
    });

    test('deleting the pass that was acknowledged brings the alert back', () {
      // « Vu » posé quand le dernier passage était f4 ; f4 a été supprimé.
      final progress = derive(
        three,
        acknowledgements: [acknowledgement(ref('a', 1), lastAttempt: 'f4')],
      );

      expect(progress.activeAlerts.single.consecutiveFailures, 3);
      expect(progress.acknowledgedAlerts, isEmpty);
    });

    test('an acknowledgement of the previous last pass does not match', () {
      final progress = derive(
        three,
        acknowledgements: [acknowledgement(ref('a', 1), lastAttempt: 'f2')],
      );

      expect(progress.activeAlerts.single.exercise, ref('a', 1));
    });

    test('the most recent acknowledgement of an exercise wins', () {
      final progress = derive(
        three,
        acknowledgements: [
          acknowledgement(ref('a', 1), lastAttempt: 'f3', day: 6, id: 'k2'),
          acknowledgement(ref('a', 1), lastAttempt: 'f2', day: 7, id: 'k3'),
        ],
      );

      // Le plus récent (k3) vise f2 : l'alerte est active.
      expect(progress.activeAlerts, hasLength(1));
    });

    test('ignores the acknowledgements of another student', () {
      final progress = derive(
        three,
        acknowledgements: [
          acknowledgement(ref('a', 1), lastAttempt: 'f3', student: 's2'),
        ],
      );

      expect(progress.activeAlerts, hasLength(1));
    });

    test('only the acknowledged exercise is masked', () {
      final progress = derive(
        [
          ...three,
          for (var i = 1; i <= 3; i++)
            attempt(ref('a', 2), potted: 0, dayOfMonth: i, id: 'g$i'),
        ],
        acknowledgements: [acknowledgement(ref('a', 1), lastAttempt: 'f3')],
      );

      expect(progress.activeAlerts.map((r) => r.exercise), [ref('a', 2)]);
    });
  });

  group('toStart', () {
    test('is true without any attempt nor acquired block', () {
      expect(derive([]).toStart, isTrue);
    });

    test('is false after attempts that validate nothing', () {
      final progress = derive([
        attempt(ref('a', 1), potted: 0, id: '1'),
        attempt(ref('a', 1), potted: 0, dayOfMonth: 2, id: '2'),
      ]);

      expect(progress.validated, isEmpty);
      expect(progress.toStart, isFalse);
    });

    test('is false for a block acquired at placement', () {
      expect(derive([], acquisitions: [acquisition('a')]).toStart, isFalse);
    });
  });
}
