import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_planner.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/default_session_shapes.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

/// 1 passage réussi valide un exercice (passesRequired: 1).
final _config = RulesConfig(passesRequired: 1);

/// L'élève [name] a validé les exercices [numbers] du bloc [blockId].
List<ExerciseAttempt> validated(
  String name,
  String blockId,
  List<int> numbers,
) => [
  for (final n in numbers)
    attempt(ref(blockId, n), potted: 3, student: name, id: '$name-$blockId$n'),
];

Map<StudentId, StudentProgress> progress(
  Map<String, List<ExerciseAttempt>> byStudent, {
  RulesConfig? config,
}) => {
  for (final entry in byStudent.entries)
    StudentId(entry.key): StudentProgress.derive(
      studentId: StudentId(entry.key),
      attempts: entry.value,
      rates: buildCatalogue().rates,
      config: config ?? _config,
    ),
};

void main() {
  final cat = buildCatalogue();

  SessionPlan plan(
    Map<String, List<ExerciseAttempt>> byStudent, {
    Audience audience = Audience.children,
    RulesConfig? config,
  }) => planSession(
    catalogue: cat,
    audience: audience,
    progress: progress(byStudent, config: config),
    groupSessions: const [],
    config: config ?? _config,
  );

  test('refuses a group without expected students', () {
    expect(() => plan({}), violation(InvariantCode.noStudents));
  });

  test('refuses when every student finished the level', () {
    final all = [
      ...validated('s1', 'a', [1, 2, 3]),
      ...validated('s1', 'b', [1, 2, 3]),
      ...validated('s1', 'c', [1, 2, 3]),
    ];

    expect(() => plan({'s1': all}), violation(InvariantCode.nothingToTeach));
  });

  test('starts with the first block for a student without history', () {
    final p = plan({'s1': []});

    expect(p.mainBlockId, 'a');
    expect(p.exercises, [ref('a', 1), ref('a', 2)]);
  });

  test('picks the block most students work on', () {
    final p = plan({
      's1': validated('s1', 'a', [1, 2, 3]),
      's2': validated('s2', 'a', [1, 2, 3]),
      's3': [],
    });

    expect(p.mainBlockId, 'b');
    expect(p.exercises.first, ref('b', 1));
  });

  test('breaks a tie with the smaller teaching order', () {
    final p = plan({
      's1': validated('s1', 'a', [1, 2, 3]),
      's2': [],
    });

    expect(p.mainBlockId, 'a');
  });

  test('starts from the most frequent exercise of the block', () {
    final p = plan({
      's1': [],
      's2': validated('s2', 'a', [1]),
      's3': validated('s3', 'a', [1]),
    });

    expect(p.exercises, [ref('a', 2), ref('a', 3)]);
  });

  test('breaks an exercise tie with the smaller number', () {
    final p = plan({
      's1': [],
      's2': validated('s2', 'a', [1, 2]),
    });

    expect(p.exercises.first, ref('a', 1));
  });

  test('ignores students who finished when choosing the block', () {
    final all = [
      ...validated('s1', 'a', [1, 2, 3]),
      ...validated('s1', 'b', [1, 2, 3]),
      ...validated('s1', 'c', [1, 2, 3]),
    ];

    final p = plan({
      's1': all,
      's2': validated('s2', 'a', [1, 2, 3]),
    });

    expect(p.mainBlockId, 'b');
  });

  test('completes with the previous exercise at the end of the block', () {
    final p = plan({
      's1': validated('s1', 'a', [1, 2]),
    });

    expect(p.exercises, [ref('a', 3), ref('a', 2)]);
  });

  test('uses the configured number of exercises', () {
    final shapes = {
      Audience.children: SessionShape(
        phases: defaultSessionShapes[Audience.children]!.phases,
        exerciseCount: 3,
        recallCount: 0,
      ),
      Audience.adults: defaultSessionShapes[Audience.adults]!,
    };

    final p = plan({
      's1': validated('s1', 'a', [1, 2]),
    }, config: RulesConfig(passesRequired: 1, shapes: shapes));

    expect(p.exercises, [ref('a', 3), ref('a', 2), ref('a', 1)]);
  });

  test('never plans more exercises than the block holds', () {
    final shapes = {
      Audience.children: SessionShape(
        phases: defaultSessionShapes[Audience.children]!.phases,
        exerciseCount: 6,
        recallCount: 0,
      ),
      Audience.adults: defaultSessionShapes[Audience.adults]!,
    };

    final p = plan({
      's1': [],
    }, config: RulesConfig(passesRequired: 1, shapes: shapes));

    expect(p.exercises, hasLength(3));
  });

  test('plans distinct exercises, each at most twice per session', () {
    final p = plan({'s1': []});

    expect(p.exercises.toSet(), hasLength(p.exercises.length));
    expect(p.maxPassesPerExercise, 2);
  });

  group('durations', () {
    test('children: 90 minutes, phases 10/20/35/20/5', () {
      final p = plan({'s1': []});

      expect(p.audience, Audience.children);
      expect(p.durationMinutes, 90);
      expect(p.phasesMinutes, 90);
      expect(p.phases.map((s) => s.minutes), [10, 20, 35, 20, 5]);
      expect(p.phases.map((s) => s.phase), SessionPhase.values);
    });

    test('adults: 120 minutes, phases 10/25/50/25/10', () {
      final p = plan({'s1': []}, audience: Audience.adults);

      expect(p.durationMinutes, 120);
      expect(p.phasesMinutes, 120);
      expect(p.phases.map((s) => s.minutes), [10, 25, 50, 25, 10]);
    });
  });

  group('recall', () {
    final failedOnA = [
      ...validated('s1', 'a', [1, 2, 3]),
      attempt(ref('a', 2), potted: 1, dayOfMonth: 5, id: 'late-fail'),
    ];

    test('adults get the failed notion as recall', () {
      final p = plan({'s1': failedOnA}, audience: Audience.adults);

      expect(p.mainBlockId, 'b');
      expect(p.recallBlockId, 'a');
      expect(p.recallExercise, ref('a', 2));
      expect(p.plannedExercises, [ref('b', 1), ref('b', 2), ref('a', 2)]);
    });

    test('children never get a recall', () {
      final p = plan({'s1': failedOnA});

      expect(p.recallBlockId, isNull);
      expect(p.recallExercise, isNull);
      expect(p.recallReason, isNull);
      expect(p.plannedExercises, p.exercises);
    });

    test('adults without anything to recall get none', () {
      final p = plan({
        's1': validated('s1', 'a', [1, 2, 3]),
      }, audience: Audience.adults);

      expect(p.recallBlockId, isNull);
    });
  });
}
