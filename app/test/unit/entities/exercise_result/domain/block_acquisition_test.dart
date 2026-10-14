import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

BlockAcquisition build({String blockId = 'a', DateTime? date}) =>
    BlockAcquisition(
      id: const AcquisitionId('q1'),
      studentId: const StudentId('s1'),
      blockId: blockId,
      date: date ?? day(5),
      source: AcquisitionSource.placement,
    );

void main() {
  test('keeps its fields', () {
    final acquisition = build();

    expect(acquisition.id, const AcquisitionId('q1'));
    expect(acquisition.studentId, const StudentId('s1'));
    expect(acquisition.blockId, 'a');
    expect(acquisition.date, day(5));
    expect(acquisition.source, AcquisitionSource.placement);
  });

  test('refuses a blank block', () {
    expect(
      () => build(blockId: '  '),
      violation(InvariantCode.invalidExerciseRef),
    );
  });

  test('refuses a date that is not normalized to the day', () {
    expect(
      () => build(date: DateTime(2026, 10, 5, 14, 30)),
      violation(InvariantCode.invalidRange),
    );
  });

  test('is read back from its stored name', () {
    expect(AcquisitionSource.values.byName('placement'), isNotNull);
    expect(AcquisitionSource.placement.name, 'placement');
  });
}
