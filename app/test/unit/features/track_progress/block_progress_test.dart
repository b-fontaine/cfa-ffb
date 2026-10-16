import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

final _config = RulesConfig(passesRequired: 1);
final TrainingBlock _block = block('a', 1);

StudentProgress progress(
  List<ExerciseAttempt> attempts, [
  List<BlockAcquisition> acquisitions = const [],
]) => StudentProgress.derive(
  studentId: const StudentId('s1'),
  attempts: attempts,
  acquisitions: acquisitions,
  rates: buildCatalogue().rates,
  config: _config,
);

BlockProgress of(
  List<ExerciseAttempt> attempts, {
  int sessionsSpent = 0,
  List<BlockAcquisition> acquisitions = const [],
}) => BlockProgress.of(
  block: _block,
  progress: progress(attempts, acquisitions),
  sessionsSpent: sessionsSpent,
);

ExerciseAttempt passed(int number, {int dayOfMonth = 1}) => attempt(
  ref('a', number),
  potted: 3,
  dayOfMonth: dayOfMonth,
  id: 'p$number-$dayOfMonth',
);

ExerciseAttempt failed(int number, {int dayOfMonth = 1}) => attempt(
  ref('a', number),
  potted: 0,
  dayOfMonth: dayOfMonth,
  id: 'f$number-$dayOfMonth',
);

SessionRecord session(
  String id, {
  Set<String> present = const {'s1'},
  String? main,
  String? recall,
}) => SessionRecord(
  id: SessionId(id),
  groupId: const GroupId('g'),
  seasonId: const SeasonId('season'),
  date: day(1),
  audience: Audience.children,
  present: {for (final name in present) StudentId(name)},
  mainBlockId: main,
  recallBlockId: recall,
);

void main() {
  group('status', () {
    test('notStarted without any pass', () {
      final p = of([]);

      expect(p.status, BlockStatus.notStarted);
      expect(p.validatedCount, 0);
      expect(p.exerciseCount, 3);
      expect(p.percentValidated, 0);
    });

    test('inProgress with one validated exercise of three', () {
      final p = of([passed(1)]);

      expect(p.status, BlockStatus.inProgress);
      expect(p.validatedCount, 1);
      expect(p.percentValidated, 33);
    });

    test('mastered when every exercise is validated', () {
      final p = of([passed(1), passed(2), passed(3)]);

      expect(p.status, BlockStatus.mastered);
      expect(p.percentValidated, 100);
    });

    test('inProgress with two validated exercises of three', () {
      final p = of([passed(1), passed(2)]);

      expect(p.status, BlockStatus.inProgress);
      expect(p.percentValidated, 66);
    });

    test('toReview when an exercise has an active alert', () {
      final p = of([
        failed(1),
        failed(1, dayOfMonth: 2),
        failed(1, dayOfMonth: 3),
      ]);

      expect(p.status, BlockStatus.toReview);
    });

    test('two failures are not yet an alert', () {
      final p = of([failed(1), failed(1, dayOfMonth: 2)]);

      expect(p.status, BlockStatus.inProgress);
    });
  });

  group('R3 overdue flag', () {
    test('is false at the recommended maximum of 2 sessions', () {
      expect(of([passed(1)], sessionsSpent: 2).overdue, isFalse);
    });

    test('is true above the recommended maximum', () {
      expect(of([passed(1)], sessionsSpent: 3).overdue, isTrue);
    });

    test('is false for a mastered block whatever the sessions', () {
      final p = of([passed(1), passed(2), passed(3)], sessionsSpent: 9);

      expect(p.overdue, isFalse);
    });

    test('keeps the number of sessions spent', () {
      expect(of([], sessionsSpent: 4).sessionsSpent, 4);
    });
  });

  group('acquired at placement', () {
    test('is acquiredAtPlacement, complete and never overdue', () {
      final p = of(
        [],
        acquisitions: [acquisition('a', day: 5)],
        sessionsSpent: 9,
      );

      expect(p.status, BlockStatus.acquiredAtPlacement);
      expect(p.validatedCount, 3);
      expect(p.percentValidated, 100);
      expect(p.overdue, isFalse);
      expect(p.acquiredOn, day(5));
      expect(p.resumedCount, 0);
    });

    test('hides the alerts of the acquired exercises: never toReview', () {
      final p = of(
        [failed(1), failed(1, dayOfMonth: 2), failed(1, dayOfMonth: 3)],
        acquisitions: [acquisition('a', day: 5)],
      );

      expect(p.status, BlockStatus.acquiredAtPlacement);
    });

    test('is derived from the results once an exercise is taken over', () {
      final p = of(
        [failed(1, dayOfMonth: 6)],
        acquisitions: [acquisition('a', day: 5)],
        sessionsSpent: 1,
      );

      expect(p.status, BlockStatus.inProgress);
      expect(p.validatedCount, 2, reason: 'a2 et a3 restent acquis');
      expect(p.percentValidated, 66);
      expect(p.acquiredOn, day(5));
      expect(p.resumedCount, 1);
    });

    test('is mastered when passes and acquired exercises cover the block', () {
      final p = of(
        [passed(1, dayOfMonth: 6)],
        acquisitions: [acquisition('a', day: 5)],
      );

      expect(p.status, BlockStatus.mastered);
      expect(p.validatedCount, 3);
      expect(p.overdue, isFalse);
      expect(p.resumedCount, 1);
    });

    test('is derived from passes alone when the marker is dormant', () {
      final p = of(
        [
          passed(1, dayOfMonth: 6),
          failed(2, dayOfMonth: 6),
          failed(3, dayOfMonth: 6),
        ],
        acquisitions: [acquisition('a', day: 5)],
      );

      expect(p.status, BlockStatus.inProgress);
      expect(p.validatedCount, 1);
      expect(p.resumedCount, 3);
      expect(p.acquiredOn, day(5));
    });

    test('shows the alert of an exercise taken over', () {
      final p = of(
        [
          failed(1, dayOfMonth: 5),
          failed(1, dayOfMonth: 6),
          failed(1, dayOfMonth: 7),
        ],
        acquisitions: [acquisition('a', day: 5)],
      );

      expect(p.status, BlockStatus.toReview);
    });
  });

  group('sessionsSpentOnBlock', () {
    int spent(
      List<SessionRecord> sessions, {
      List<ExerciseAttempt> attempts = const [],
    }) => sessionsSpentOnBlock(
      block: _block,
      studentId: const StudentId('s1'),
      attempts: attempts,
      sessions: sessions,
    );

    test('is 0 without sessions', () {
      expect(spent([]), 0);
    });

    test('counts sessions where the block is the main notion', () {
      expect(spent([session('x1', main: 'a'), session('x2', main: 'b')]), 1);
    });

    test('counts sessions where the block is the recall', () {
      expect(spent([session('x1', recall: 'a', main: 'b')]), 1);
    });

    test('counts sessions with a pass on the block', () {
      final attempts = [
        attempt(ref('a', 1), potted: 3, session: 'x2', id: 'p'),
      ];

      expect(spent([session('x1'), session('x2')], attempts: attempts), 1);
    });

    test('counts a session once even when several criteria match', () {
      final attempts = [
        attempt(ref('a', 1), potted: 3, id: 'p'),
        attempt(ref('a', 2), potted: 3, id: 'q'),
      ];

      expect(spent([session('x1', main: 'a')], attempts: attempts), 1);
    });

    test('ignores sessions the student missed', () {
      expect(
        spent([
          session('x1', present: {'other'}, main: 'a'),
        ]),
        0,
      );
    });

    test('ignores passes on other blocks', () {
      final attempts = [attempt(ref('b', 1), potted: 3, id: 'p')];

      expect(spent([session('x1')], attempts: attempts), 0);
    });
  });
}
