import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

final TrainingBlock _block = block('a', 1);

TechniqueSummary summary(
  List<ExerciseAttempt> attempts, {
  List<BlockAcquisition> acquisitions = const [],
  List<AlertAcknowledgement> acknowledgements = const [],
}) => techniqueSummary(
  blockId: _block.id,
  exercises: _block.exerciseRefs,
  progress: StudentProgress.derive(
    studentId: const StudentId('s1'),
    attempts: attempts,
    acquisitions: acquisitions,
    acknowledgements: acknowledgements,
    rates: buildCatalogue().rates,
    config: RulesConfig(passesRequired: 1),
  ),
);

ExerciseAttempt pass(int number, {int dayOfMonth = 1}) => attempt(
  ref('a', number),
  potted: 3,
  dayOfMonth: dayOfMonth,
  id: 'p$number-$dayOfMonth',
);

ExerciseAttempt miss(int number, {int dayOfMonth = 1}) => attempt(
  ref('a', number),
  potted: 0,
  dayOfMonth: dayOfMonth,
  id: 'f$number-$dayOfMonth',
);

List<ExerciseAttempt> threeMisses() => [
  miss(1),
  miss(1, dayOfMonth: 2),
  miss(1, dayOfMonth: 3),
];

void main() {
  test('a fresh block is not started with every cell to do', () {
    final result = summary([]);

    expect(result.status, BlockStatus.notStarted);
    expect(result.total, 3);
    expect(result.todo, 3);
    expect(result.doneCount, 0);
    expect(result.cells, hasLength(3));
  });

  test('counts validated, in progress and to do exercises', () {
    final result = summary([pass(1), miss(2)]);

    expect(result.status, BlockStatus.inProgress);
    expect(result.validated, 1);
    expect(result.inProgress, 1);
    expect(result.todo, 1);
    expect(result.acquired, 0);
    expect(result.doneCount, 1);
  });

  test('every exercise validated by passes is mastered', () {
    final result = summary([pass(1), pass(2), pass(3)]);

    expect(result.status, BlockStatus.mastered);
    expect(result.validated, 3);
    expect(result.isFinished, isTrue);
  });

  test('a block marked acquired is acquired at placement, not mastered', () {
    final result = summary([], acquisitions: [acquisition('a')]);

    expect(result.status, BlockStatus.acquiredAtPlacement);
    expect(result.acquired, 3);
    expect(result.validated, 0);
    expect(result.doneCount, 3);
    expect(result.isFinished, isTrue);
  });

  test('a block partly taken back after placement is no longer acquired', () {
    final result = summary(
      [miss(1, dayOfMonth: 6)],
      acquisitions: [acquisition('a', day: 5)],
    );

    expect(result.status, isNot(BlockStatus.acquiredAtPlacement));
    expect(result.acquired, 2);
    expect(result.inProgress, 1);
    expect(result.doneCount, 2);
    expect(result.isFinished, isFalse);
  });

  test('an active alert makes the block to review', () {
    final result = summary(threeMisses());

    expect(result.status, BlockStatus.toReview);
    expect(result.alerted, 1);
  });

  test('an acknowledged alert gives the block back its in progress status', () {
    final result = summary(
      threeMisses(),
      acknowledgements: [acknowledgement(ref('a', 1), lastAttempt: 'f1-3')],
    );

    expect(result.status, BlockStatus.inProgress);
    expect(result.alerted, 0);
  });
}
