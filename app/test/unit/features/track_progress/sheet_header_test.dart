import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/features/track_progress/domain/sheet_header.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

final _config = RulesConfig(passesRequired: 2);
int _ids = 0;

ExerciseAttempt pass(String block, int number, {int dayOfMonth = 1}) => attempt(
  ref(block, number),
  potted: 3,
  dayOfMonth: dayOfMonth,
  id: 'p${_ids++}',
);

ExerciseAttempt miss(String block, int number, {int dayOfMonth = 1}) => attempt(
  ref(block, number),
  potted: 0,
  dayOfMonth: dayOfMonth,
  id: 'm${_ids++}',
);

/// Exercice validé par deux passages réussis.
List<ExerciseAttempt> validated(String block, int number) => [
  pass(block, number),
  pass(block, number, dayOfMonth: 2),
];

SheetHeader header(
  List<ExerciseAttempt> attempts, {
  List<BlockAcquisition> acquisitions = const [],
  List<AlertAcknowledgement> acknowledgements = const [],
}) {
  final catalogue = buildCatalogue();
  return SheetHeader.derive(
    catalogue: catalogue,
    progress: StudentProgress.derive(
      studentId: const StudentId('s1'),
      attempts: attempts,
      acquisitions: acquisitions,
      acknowledgements: acknowledgements,
      rates: catalogue.rates,
      config: _config,
    ),
    passesRequired: _config.passesRequired,
  );
}

void main() {
  test('a fresh student starts at the first exercise, with the next one', () {
    final result = header([]);

    expect(result.current, ref('a', 1));
    expect(result.next, ref('a', 2));
    expect(result.currentPassed, 0);
    expect(result.passesRequired, 2);
    expect(result.toStart, isTrue);
    expect(result.levelCompleted, isFalse);
    expect(result.finishedTechniques, 0);
    expect(result.techniqueCount, 3);
    expect(result.validatedExercises, 0);
    expect(result.exerciseCount, 9);
    expect(result.alert, isNull);
    expect(result.acknowledged, isEmpty);
  });

  test('a student who practised without validating is not to start', () {
    final result = header([pass('a', 1)]);

    expect(result.toStart, isFalse);
    expect(result.validatedExercises, 0);
    expect(result.current, ref('a', 1));
    expect(result.currentPassed, 1);
  });

  test('failed passes alone also mean the path is under way', () {
    final result = header([miss('a', 1)]);

    expect(result.toStart, isFalse);
  });

  test('a validated exercise moves the current one forward', () {
    final result = header(validated('a', 1));

    expect(result.current, ref('a', 2));
    expect(result.next, ref('a', 3));
    expect(result.toStart, isFalse);
    expect(result.validatedExercises, 1);
  });

  test('the next exercise crosses the block boundary', () {
    final result = header([
      ...validated('a', 1),
      ...validated('a', 2),
      ...validated('a', 3),
    ]);

    expect(result.current, ref('b', 1));
    expect(result.next, ref('b', 2));
    expect(result.finishedTechniques, 1);
  });

  test(
    'the current exercise is the first one not validated, never skipped',
    () {
      final result = header(validated('a', 2));

      expect(result.current, ref('a', 1));
      expect(result.next, ref('a', 3));
    },
  );

  test('the last exercise has no next one', () {
    final result = header([
      for (final block in ['a', 'b', 'c'])
        for (var n = 1; n <= 3; n++)
          if (!(block == 'c' && n == 3)) ...validated(block, n),
    ]);

    expect(result.current, ref('c', 3));
    expect(result.next, isNull);
    expect(result.levelCompleted, isFalse);
  });

  test('a finished level has neither current nor next exercise', () {
    final result = header([
      for (final block in ['a', 'b', 'c'])
        for (var n = 1; n <= 3; n++) ...validated(block, n),
    ]);

    expect(result.current, isNull);
    expect(result.next, isNull);
    expect(result.levelCompleted, isTrue);
    expect(result.finishedTechniques, 3);
    expect(result.validatedExercises, 9);
  });

  test('a block acquired at placement counts as a finished technique', () {
    final result = header([], acquisitions: [acquisition('a')]);

    expect(result.current, ref('b', 1));
    expect(result.finishedTechniques, 1);
    expect(result.validatedExercises, 3);
    expect(result.toStart, isFalse);
  });

  test('gives the successful passes of the current exercise only', () {
    final result = header([pass('a', 1), miss('a', 1, dayOfMonth: 2)]);

    expect(result.current, ref('a', 1));
    expect(result.currentPassed, 1);
  });

  test('has no alert without an active one', () {
    final result = header([miss('a', 1), miss('a', 1, dayOfMonth: 2)]);

    expect(result.alert, isNull);
  });

  test('keeps the most alarming alert and counts the others', () {
    final result = header([
      for (var d = 1; d <= 3; d++) miss('a', 1, dayOfMonth: d),
      for (var d = 1; d <= 5; d++) miss('b', 2, dayOfMonth: d),
      for (var d = 1; d <= 4; d++) miss('c', 1, dayOfMonth: d),
    ]);

    expect(result.alert!.exercise, ref('b', 2));
    expect(result.alert!.alert, AlertLevel.persistent);
    expect(result.alert!.consecutiveFailures, 5);
    expect(result.alert!.otherAlerts, 2);
  });

  test('an acknowledged alert leaves the alert and is listed as seen', () {
    final misses = [for (var d = 1; d <= 3; d++) miss('a', 1, dayOfMonth: d)];
    final result = header(
      misses,
      acknowledgements: [
        acknowledgement(ref('a', 1), lastAttempt: misses.last.id.value, day: 7),
      ],
    );

    expect(result.alert, isNull);
    final seen = result.acknowledged.single;
    expect(seen.exercise, ref('a', 1));
    expect(seen.date, day(7));
    expect(seen.consecutiveFailures, 3);
    expect(seen.alert, AlertLevel.attention);
  });

  test('when one of two alerts is seen the other stays', () {
    final first = [for (var d = 1; d <= 3; d++) miss('a', 1, dayOfMonth: d)];
    final second = [for (var d = 1; d <= 4; d++) miss('b', 1, dayOfMonth: d)];
    final result = header(
      [...first, ...second],
      acknowledgements: [
        acknowledgement(ref('b', 1), lastAttempt: second.last.id.value),
      ],
    );

    expect(result.alert!.exercise, ref('a', 1));
    expect(result.alert!.otherAlerts, 0);
    expect(result.acknowledged.single.exercise, ref('b', 1));
  });
}
