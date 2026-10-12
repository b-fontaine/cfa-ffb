import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/session_range.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

TrainingBlock build({
  String id = 'a',
  String title = 'Titre',
  int order = 1,
  List<ExerciseSpec>? exercises,
}) => TrainingBlock(
  id: id,
  title: title,
  teachingOrder: order,
  recommendedSessions: SessionRange(min: 1, max: 2),
  technicalSheets: const [2],
  exercises: exercises ?? [ExerciseSpec(ref: ref('a', 1), rate: rate())],
);

void main() {
  test('accepts contiguous exercises numbered from 1', () {
    final block = build(
      exercises: [
        ExerciseSpec(ref: ref('a', 1), rate: rate()),
        ExerciseSpec(ref: ref('a', 2), rate: rate()),
      ],
    );

    expect(block.exercises, hasLength(2));
    expect(block.duplicateInSource, isFalse);
  });

  test('refuses a block without exercises', () {
    expect(
      () => build(exercises: []),
      violation(InvariantCode.invalidCatalogue),
    );
  });

  test('refuses numbering that does not start at 1', () {
    expect(
      () => build(
        exercises: [ExerciseSpec(ref: ref('a', 2), rate: rate())],
      ),
      violation(InvariantCode.invalidCatalogue),
    );
  });

  test('refuses numbering with a gap', () {
    expect(
      () => build(
        exercises: [
          ExerciseSpec(ref: ref('a', 1), rate: rate()),
          ExerciseSpec(ref: ref('a', 3), rate: rate()),
        ],
      ),
      violation(InvariantCode.invalidCatalogue),
    );
  });

  test('refuses an exercise that belongs to another block', () {
    expect(
      () => build(
        exercises: [ExerciseSpec(ref: ref('b', 1), rate: rate())],
      ),
      violation(InvariantCode.invalidCatalogue),
    );
  });

  test('refuses a blank title', () {
    expect(() => build(title: ' '), violation(InvariantCode.invalidCatalogue));
  });

  test('refuses teaching order 0 and accepts 1', () {
    expect(() => build(order: 0), violation(InvariantCode.invalidCatalogue));
    expect(build().teachingOrder, 1);
  });
}
