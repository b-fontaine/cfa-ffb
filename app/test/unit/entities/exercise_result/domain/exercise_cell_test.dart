import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_cell.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

final TrainingBlock _block = block('a', 1);

StudentProgress derive(
  List<ExerciseAttempt> attempts, {
  List<BlockAcquisition> acquisitions = const [],
  List<AlertAcknowledgement> acknowledgements = const [],
}) => StudentProgress.derive(
  studentId: const StudentId('s1'),
  attempts: attempts,
  acquisitions: acquisitions,
  acknowledgements: acknowledgements,
  rates: buildCatalogue().rates,
  config: RulesConfig(passesRequired: 2),
);

ExerciseAttempt pass(int number, int dayOfMonth, String id) =>
    attempt(ref('a', number), potted: 3, dayOfMonth: dayOfMonth, id: id);

ExerciseAttempt miss(int number, int dayOfMonth, String id) =>
    attempt(ref('a', number), potted: 0, dayOfMonth: dayOfMonth, id: id);

List<ExerciseCell> cells(StudentProgress progress) =>
    exerciseCells(exercises: _block.exerciseRefs, progress: progress);

void main() {
  test('gives one cell per exercise, in the order of the block', () {
    final result = cells(derive([]));

    expect(result.map((c) => c.exercise), [
      ref('a', 1),
      ref('a', 2),
      ref('a', 3),
    ]);
  });

  test('an exercise without any pass is to do', () {
    final cell = cells(derive([])).first;

    expect(cell.state, ExerciseCellState.todo);
    expect(cell.passedCount, 0);
    expect(cell.alerted, isFalse);
  });

  test('an exercise with a pass below the required count is in progress', () {
    final cell = cells(derive([pass(1, 1, 'p1')])).first;

    expect(cell.state, ExerciseCellState.inProgress);
    expect(cell.passedCount, 1);
  });

  test('an exercise tried only in failure is in progress with no success', () {
    final cell = cells(derive([miss(1, 1, 'f1')])).first;

    expect(cell.state, ExerciseCellState.inProgress);
    expect(cell.passedCount, 0);
  });

  test('an exercise with the required passes is validated', () {
    final cell = cells(derive([pass(1, 1, 'p1'), pass(1, 2, 'p2')])).first;

    expect(cell.state, ExerciseCellState.validated);
    expect(cell.passedCount, 2);
  });

  test('an exercise of a block marked acquired is acquired', () {
    final result = cells(derive([], acquisitions: [acquisition('a', day: 5)]));

    expect(
      result.map((c) => c.state),
      everyElement(ExerciseCellState.acquired),
    );
  });

  test('acquired wins over passes validated before the placement', () {
    final result = cells(
      derive(
        [pass(1, 1, 'p1'), pass(1, 2, 'p2')],
        acquisitions: [acquisition('a', day: 5)],
      ),
    );

    expect(result.first.state, ExerciseCellState.acquired);
  });

  test('a pass on the day of the placement takes the exercise back', () {
    final result = cells(
      derive([pass(2, 5, 'p1')], acquisitions: [acquisition('a', day: 5)]),
    );

    expect(result.map((c) => c.state), [
      ExerciseCellState.acquired,
      ExerciseCellState.inProgress,
      ExerciseCellState.acquired,
    ]);
    expect(result[1].passedCount, 1);
  });

  test('an exercise taken back and validated is validated, not acquired', () {
    final result = cells(
      derive(
        [pass(2, 5, 'p1'), pass(2, 6, 'p2')],
        acquisitions: [acquisition('a', day: 5)],
      ),
    );

    expect(result[1].state, ExerciseCellState.validated);
  });

  test('an active alert marks an exercise in progress as alerted', () {
    final result = cells(
      derive([miss(1, 1, 'f1'), miss(1, 2, 'f2'), miss(1, 3, 'f3')]),
    );

    expect(result.first.state, ExerciseCellState.inProgress);
    expect(result.first.alerted, isTrue);
    expect(result[1].alerted, isFalse);
  });

  test('an acknowledged alert no longer marks the cell', () {
    final result = cells(
      derive(
        [miss(1, 1, 'f1'), miss(1, 2, 'f2'), miss(1, 3, 'f3')],
        acknowledgements: [acknowledgement(ref('a', 1), lastAttempt: 'f3')],
      ),
    );

    expect(result.first.alerted, isFalse);
    expect(result.first.state, ExerciseCellState.inProgress);
  });

  test('an acquired exercise is never alerted', () {
    final result = cells(
      derive(
        [miss(1, 1, 'f1'), miss(1, 2, 'f2'), miss(1, 3, 'f3')],
        acquisitions: [acquisition('a', day: 5)],
      ),
    );

    expect(result.first.state, ExerciseCellState.acquired);
    expect(result.first.alerted, isFalse);
  });
}
