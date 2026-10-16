import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/review_session/domain/review_session.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  final a1 = ref('a', 1);
  final a2 = ref('a', 2);
  final b1 = ref('b', 1);
  final catalogue = buildCatalogue();
  var ids = 0;

  SessionRecord record({Set<String> present = const {'s1', 's2'}}) =>
      SessionRecord(
        id: const SessionId('today'),
        groupId: const GroupId('g1'),
        seasonId: const SeasonId('season'),
        date: day(12),
        audience: Audience.children,
        present: {for (final name in present) StudentId(name)},
      );

  /// Un passage de la saisie du jour (réussi : 3 sur 5, échoué : 2 sur 5).
  ExerciseAttempt today(
    String student,
    ExerciseRef exercise, {
    bool passed = true,
    int passIndex = 1,
  }) => attempt(
    exercise,
    potted: passed ? 3 : 2,
    student: student,
    session: 'today',
    dayOfMonth: 12,
    passIndex: passIndex,
    id: 't${ids++}',
  );

  /// Un passage d'une séance antérieure (jour [dayOfMonth]).
  ExerciseAttempt before(
    String student,
    ExerciseRef exercise, {
    bool passed = true,
    int dayOfMonth = 3,
  }) => attempt(
    exercise,
    potted: passed ? 3 : 2,
    student: student,
    session: 'x$dayOfMonth',
    dayOfMonth: dayOfMonth,
    id: 'b${ids++}',
  );

  List<ExerciseAttempt> repeat(
    int times,
    ExerciseAttempt Function(int) build,
  ) => [for (var i = 0; i < times; i++) build(i)];

  SessionOutcome review(
    List<ExerciseAttempt> attempts, {
    SessionRecord? of,
    RulesConfig? config,
    List<dynamic> acquisitions = const [],
  }) => reviewSession(
    record: of ?? record(),
    attempts: attempts,
    acquisitions: [
      for (final block in acquisitions.cast<String>()) acquisition(block),
    ],
    catalogue: catalogue,
    config: config ?? RulesConfig(),
  );

  group('passes', () {
    test('has none for a record without any pass', () {
      final outcome = review(const []);

      expect(outcome.totalPasses, 0);
      expect(outcome.totalPassed, 0);
      expect(outcome.byExercise, isEmpty);
      expect(outcome.isEmpty, isTrue);
    });

    test('counts the passes entered per exercise, in teaching order', () {
      final outcome = review([
        today('s1', b1),
        today('s1', a2, passed: false),
        today('s2', a2),
        today('s2', a2, passIndex: 2),
      ]);

      expect(outcome.totalPasses, 4);
      expect(outcome.totalPassed, 3);
      expect(
        [
          for (final line in outcome.byExercise)
            (line.exercise, line.passes, line.passed),
        ],
        [(a2, 3, 2), (b1, 1, 1)],
      );
    });

    test('ignores the passes of other sessions', () {
      final outcome = review([before('s1', a1), today('s1', a1)]);

      expect(outcome.totalPasses, 1);
    });
  });

  group('validations', () {
    test('lists an exercise validated by this record', () {
      final outcome = review([
        ...repeat(4, (_) => before('s1', a1)),
        today('s1', a1),
      ]);

      expect(
        [for (final v in outcome.validations) (v.studentId.value, v.exercise)],
        [('s1', a1)],
      );
    });

    test('does not list an exercise validated by an earlier session', () {
      final outcome = review([
        ...repeat(5, (_) => before('s1', a1)),
        today('s1', a1),
      ]);

      expect(outcome.validations, isEmpty);
    });

    test('does not list an exercise still in progress', () {
      final outcome = review([
        ...repeat(3, (_) => before('s1', a1)),
        today('s1', a1),
      ]);

      expect(outcome.validations, isEmpty);
    });

    test('lists it once when the record itself holds the passes', () {
      final outcome = review([
        today('s1', a1),
        today('s1', a1, passIndex: 2),
      ], config: RulesConfig(passesRequired: 2));

      expect(outcome.validations, hasLength(1));
    });

    test('follows the passes required: 2 validates, 5 does not', () {
      final attempts = [before('s1', a1), today('s1', a1)];

      expect(
        review(attempts, config: RulesConfig(passesRequired: 2)).validations,
        hasLength(1),
      );
      expect(review(attempts, config: RulesConfig()).validations, isEmpty);
    });

    test('an exercise failed today after being validated stays validated', () {
      final outcome = review([
        ...repeat(5, (_) => before('s1', a1)),
        today('s1', a1, passed: false),
      ]);

      expect(outcome.validations, isEmpty);
    });

    test('does not list an exercise that was acquired at placement', () {
      final outcome = review(
        [today('s1', a1)],
        acquisitions: ['a'],
        config: RulesConfig(passesRequired: 1),
      );

      expect(outcome.validations, isEmpty);
    });

    test('sorts by student then by teaching order', () {
      final outcome = review([
        today('s2', a1),
        today('s1', b1),
        today('s1', a2),
      ], config: RulesConfig(passesRequired: 1));

      expect(
        [for (final v in outcome.validations) (v.studentId.value, v.exercise)],
        [('s1', a2), ('s1', b1), ('s2', a1)],
      );
    });
  });

  group('students', () {
    test('names the present students without any pass', () {
      final outcome = review([today('s1', a1)]);

      expect([for (final id in outcome.unrated) id.value], ['s2']);
    });

    test('everyone present is unrated for an empty record', () {
      final outcome = review(const []);

      expect([for (final id in outcome.unrated) id.value], ['s1', 's2']);
    });

    test('lists present students with an active alert', () {
      final outcome = review([
        ...repeat(3, (i) => before('s2', a1, passed: false, dayOfMonth: 2 + i)),
        today('s1', a1),
      ]);

      expect(
        [for (final w in outcome.watched) (w.studentId.value, w.exercise)],
        [('s2', a1)],
      );
      expect(outcome.watched.single.alert, AlertLevel.attention);
    });

    test('does not list an absent student with an active alert', () {
      final outcome = review([
        ...repeat(3, (i) => before('s3', a1, passed: false, dayOfMonth: 2 + i)),
        today('s1', a1),
      ]);

      expect(outcome.watched, isEmpty);
    });

    test('counts the failures of the record in the alert', () {
      final outcome = review([
        before('s1', a1, passed: false, dayOfMonth: 2),
        before('s1', a1, passed: false),
        today('s1', a1, passed: false),
      ]);

      expect(outcome.watched.single.consecutiveFailures, 3);
    });
  });
}
