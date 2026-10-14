import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/suggest_session/domain/recall_selector.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

final _config = RulesConfig(passesRequired: 1);

int _ids = 0;

/// Passage de [student] sur [exercise] : réussi (3/5) ou raté (2/5).
ExerciseAttempt pass(
  String student,
  String exercise, {
  required bool passed,
  required int dayOfMonth,
  int passIndex = 1,
}) {
  final parts = exercise.split(' ');
  return attempt(
    ref(parts.first, int.parse(parts.last)),
    potted: passed ? 3 : 2,
    student: student,
    dayOfMonth: dayOfMonth,
    passIndex: passIndex,
    id: 'p${_ids++}',
  );
}

Map<StudentId, StudentProgress> progress(
  Map<String, List<ExerciseAttempt>> byStudent, {
  RulesConfig? config,
  List<BlockAcquisition> acquisitions = const [],
}) => {
  for (final entry in byStudent.entries)
    StudentId(entry.key): StudentProgress.derive(
      studentId: StudentId(entry.key),
      attempts: entry.value,
      acquisitions: acquisitions,
      rates: buildCatalogue().rates,
      config: config ?? _config,
    ),
};

/// Séance du groupe où [present] étaient là, le [dayOfMonth].
SessionRecord session(int dayOfMonth, Set<String> present) => SessionRecord(
  id: SessionId('s$dayOfMonth'),
  groupId: const GroupId('g'),
  seasonId: const SeasonId('season'),
  date: day(dayOfMonth),
  audience: Audience.adults,
  present: {for (final name in present) StudentId(name)},
);

RecallSuggestion? select(
  Map<String, List<ExerciseAttempt>> byStudent, {
  List<SessionRecord> sessions = const [],
  String main = 'c',
  RulesConfig? config,
}) => selectRecall(
  catalogue: buildCatalogue(),
  progress: progress(byStudent, config: config),
  groupSessions: sessions,
  mainBlockId: main,
  config: config ?? _config,
);

void main() {
  test('suggests nothing when no other block was started', () {
    expect(select({'s1': []}), isNull);
  });

  test('suggests nothing when everything was passed recently', () {
    expect(
      select({
        's1': [pass('s1', 'a 1', passed: true, dayOfMonth: 1)],
      }),
      isNull,
    );
  });

  test('never recalls the main block', () {
    final failedMain = [pass('s1', 'c 1', passed: false, dayOfMonth: 1)];

    expect(select({'s1': failedMain}), isNull);
  });

  group('last pass failed', () {
    test('recalls the block and the failed exercise', () {
      final result = select({
        's1': [
          pass('s1', 'a 1', passed: true, dayOfMonth: 1),
          pass('s1', 'a 2', passed: false, dayOfMonth: 2),
        ],
      });

      expect(result!.blockId, 'a');
      expect(result.exercise, ref('a', 2));
    });

    test('is not triggered when the failure is followed by a pass', () {
      final result = select({
        's1': [
          pass('s1', 'a 1', passed: false, dayOfMonth: 1),
          pass('s1', 'a 1', passed: true, dayOfMonth: 2),
        ],
      });

      expect(result, isNull);
    });

    test('takes the latest pass of the block across exercises', () {
      final result = select({
        's1': [
          pass('s1', 'a 2', passed: false, dayOfMonth: 1),
          pass('s1', 'a 1', passed: true, dayOfMonth: 2),
        ],
      });

      expect(result, isNull);
    });

    test('uses the pass index to order two passes of the same day', () {
      final failedLast = select({
        's1': [
          pass('s1', 'a 1', passed: true, dayOfMonth: 1),
          pass('s1', 'a 2', passed: false, dayOfMonth: 1, passIndex: 2),
        ],
      });
      final passedLast = select({
        's1': [
          pass('s1', 'a 2', passed: false, dayOfMonth: 1),
          pass('s1', 'a 1', passed: true, dayOfMonth: 1, passIndex: 2),
        ],
      });

      expect(failedLast!.exercise, ref('a', 2));
      expect(passedLast, isNull);
    });
  });

  group('last pass of a block', () {
    test('on the same day and pass index, the later exercise is last', () {
      final passedLast = select({
        's1': [
          pass('s1', 'a 1', passed: false, dayOfMonth: 1),
          pass('s1', 'a 2', passed: true, dayOfMonth: 1),
        ],
      });
      final failedLast = select({
        's1': [
          pass('s1', 'a 1', passed: true, dayOfMonth: 1),
          pass('s1', 'a 2', passed: false, dayOfMonth: 1),
        ],
      });

      expect(passedLast, isNull);
      expect(failedLast!.exercise, ref('a', 2));
    });

    test('a later pass index wins over a later exercise number', () {
      final result = select({
        's1': [
          pass('s1', 'a 2', passed: true, dayOfMonth: 1),
          pass('s1', 'a 1', passed: false, dayOfMonth: 1, passIndex: 2),
        ],
      });

      expect(result!.exercise, ref('a', 1));
    });
  });

  group('reasons', () {
    test('group failure when at least 50 percent of students failed', () {
      final result = select({
        's1': [pass('s1', 'a 1', passed: false, dayOfMonth: 1)],
        's2': [pass('s2', 'a 1', passed: true, dayOfMonth: 1)],
      });

      expect(result!.reason, RecallReason.groupFailure);
    });

    test('group failure when every student failed (above 50 percent)', () {
      final result = select({
        's1': [pass('s1', 'a 1', passed: false, dayOfMonth: 1)],
        's2': [pass('s2', 'a 1', passed: false, dayOfMonth: 1)],
        's3': [pass('s3', 'a 1', passed: false, dayOfMonth: 1)],
      });

      expect(result!.reason, RecallReason.groupFailure);
    });

    test('last failed when fewer than 50 percent failed (1 of 3)', () {
      final result = select({
        's1': [pass('s1', 'a 1', passed: false, dayOfMonth: 1)],
        's2': [pass('s2', 'a 1', passed: true, dayOfMonth: 1)],
        's3': [pass('s3', 'a 1', passed: true, dayOfMonth: 1)],
      });

      expect(result!.reason, RecallReason.lastFailed);
    });

    test('a configured share of 100 percent needs every student to fail', () {
      final strict = RulesConfig(
        passesRequired: 1,
        groupFailureSharePercent: 100,
      );
      final one = select({
        's1': [pass('s1', 'a 1', passed: false, dayOfMonth: 1)],
        's2': [pass('s2', 'a 1', passed: true, dayOfMonth: 1)],
      }, config: strict);
      final both = select({
        's1': [pass('s1', 'a 1', passed: false, dayOfMonth: 1)],
        's2': [pass('s2', 'a 1', passed: false, dayOfMonth: 1)],
      }, config: strict);

      expect(one!.reason, RecallReason.lastFailed);
      expect(both!.reason, RecallReason.groupFailure);
    });

    test('active alert outranks a plain failure', () {
      final result = select({
        's1': [
          pass('s1', 'a 1', passed: false, dayOfMonth: 1),
          pass('s1', 'a 1', passed: false, dayOfMonth: 2),
          pass('s1', 'a 1', passed: false, dayOfMonth: 3),
        ],
        's2': [pass('s2', 'a 1', passed: true, dayOfMonth: 1)],
        's3': [pass('s3', 'a 1', passed: true, dayOfMonth: 1)],
      });

      expect(result!.reason, RecallReason.activeAlert);
      expect(result.exercise, ref('a', 1));
    });

    test('stale when not practised for 4 group sessions', () {
      final result = select(
        {
          's1': [pass('s1', 'a 1', passed: true, dayOfMonth: 1)],
        },
        sessions: [
          for (var d = 2; d <= 5; d++) session(d, {'s1'}),
        ],
      );

      expect(result!.reason, RecallReason.stale);
      expect(result.blockId, 'a');
    });

    test('not stale after only 3 group sessions', () {
      final result = select(
        {
          's1': [pass('s1', 'a 1', passed: true, dayOfMonth: 1)],
        },
        sessions: [
          for (var d = 2; d <= 4; d++) session(d, {'s1'}),
        ],
      );

      expect(result, isNull);
    });

    test('stale counts only sessions the student attended', () {
      final result = select(
        {
          's1': [pass('s1', 'a 1', passed: true, dayOfMonth: 1)],
        },
        sessions: [
          for (var d = 2; d <= 5; d++) session(d, {'someone'}),
        ],
      );

      expect(result, isNull);
    });

    test('stale ignores sessions on or before the last practice day', () {
      final result = select(
        {
          's1': [pass('s1', 'a 1', passed: true, dayOfMonth: 5)],
        },
        sessions: [
          for (var d = 1; d <= 5; d++) session(d, {'s1'}),
        ],
      );

      expect(result, isNull);
    });

    test('follows a configured staleness of 2 sessions', () {
      final config = RulesConfig(passesRequired: 1, recallStaleSessions: 2);

      final result = select(
        {
          's1': [pass('s1', 'a 1', passed: true, dayOfMonth: 1)],
        },
        sessions: [
          session(2, {'s1'}),
          session(3, {'s1'}),
        ],
        config: config,
      );

      expect(result!.reason, RecallReason.stale);
    });
  });

  group('ranking', () {
    test('prefers the block with a group failure over a stale block', () {
      final result = select(
        {
          's1': [
            pass('s1', 'a 1', passed: true, dayOfMonth: 1),
            pass('s1', 'b 1', passed: false, dayOfMonth: 2),
          ],
        },
        sessions: [
          for (var d = 3; d <= 6; d++) session(d, {'s1'}),
        ],
      );

      expect(result!.blockId, 'b');
    });

    test('prefers the active alert block over a plain failed block', () {
      final result = select({
        's1': [
          pass('s1', 'a 1', passed: false, dayOfMonth: 1),
          pass('s1', 'b 1', passed: false, dayOfMonth: 1),
          pass('s1', 'b 1', passed: false, dayOfMonth: 2),
          pass('s1', 'b 1', passed: false, dayOfMonth: 3),
          pass('s1', 'a 1', passed: true, dayOfMonth: 4),
        ],
      });

      expect(result!.blockId, 'b');
    });

    test('with equal priority prefers the lower relative score', () {
      final result = select({
        's1': [
          pass('s1', 'a 1', passed: false, dayOfMonth: 1),
          attempt(ref('b', 1), potted: 0, id: 'z'),
        ],
      });

      expect(result!.blockId, 'b');
    });

    test('with equal scores prefers the oldest practice', () {
      final result = select({
        's1': [
          pass('s1', 'b 1', passed: false, dayOfMonth: 1),
          pass('s1', 'a 1', passed: false, dayOfMonth: 2),
        ],
      });

      expect(result!.blockId, 'b');
    });

    test(
      'with equal scores prefers the block whose oldest practice is older',
      () {
        // Bloc a : élèves aux jours 5 et 6, bloc b : aux jours 1 et 9.
        final result = select({
          's1': [
            pass('s1', 'a 1', passed: false, dayOfMonth: 5),
            pass('s1', 'b 1', passed: false, dayOfMonth: 1),
          ],
          's2': [
            pass('s2', 'a 1', passed: false, dayOfMonth: 6),
            pass('s2', 'b 1', passed: false, dayOfMonth: 9),
          ],
        });

        expect(result!.blockId, 'b');
      },
    );

    test('with everything equal prefers the smaller teaching order', () {
      final result = select({
        's1': [
          pass('s1', 'b 1', passed: false, dayOfMonth: 1),
          pass('s1', 'a 1', passed: false, dayOfMonth: 1),
        ],
      });

      expect(result!.blockId, 'a');
    });

    test('inside a block prefers the exercise with an active alert', () {
      final result = select({
        's1': [
          pass('s1', 'a 1', passed: false, dayOfMonth: 1),
          pass('s1', 'a 1', passed: false, dayOfMonth: 2),
          pass('s1', 'a 1', passed: false, dayOfMonth: 3),
          attempt(ref('a', 2), potted: 0, dayOfMonth: 4, id: 'q'),
        ],
      });

      expect(result!.exercise, ref('a', 1));
    });

    test('inside a block prefers the lower score, then the lower number', () {
      final lowerScore = select({
        's1': [
          pass('s1', 'a 1', passed: false, dayOfMonth: 1),
          attempt(ref('a', 2), potted: 0, dayOfMonth: 2, id: 'q'),
        ],
      });
      final sameScore = select({
        's1': [
          pass('s1', 'a 2', passed: false, dayOfMonth: 1),
          pass('s1', 'a 1', passed: false, dayOfMonth: 2),
        ],
      });

      expect(lowerScore!.exercise, ref('a', 2));
      expect(sameScore!.exercise, ref('a', 1));
    });
  });
}
