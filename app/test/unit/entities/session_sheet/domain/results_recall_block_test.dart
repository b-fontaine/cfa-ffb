import 'package:billard_cfa/features/run_sheet/domain/results_recall_block.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/session_sheet_fixtures.dart';

void main() {
  final all = catalogueFixture();
  final byId = {for (final s in all) s.id.value: s};

  test('has no recall block for the first session of the catalogue', () {
    expect(resultsRecallBlock(byId['posture-1']!, all), isNull);
  });

  test('takes the block of the previous technique for a first part', () {
    expect(resultsRecallBlock(byId['demi-bille-1']!, all), 'posture');
  });

  test('skips the previous part of the same block for a later part', () {
    expect(resultsRecallBlock(byId['demi-bille-2']!, all), 'posture');
  });

  test('looks past a part whose block is the same as the main block', () {
    // quart-1 (bloc quart-finesses) suit demi-bille-2 (bloc demi-bille).
    expect(resultsRecallBlock(byId['quart-1']!, all), 'demi-bille');
    final finesse = buildSheet(
      technique: 'finesse',
      order: 5,
      previous: 'quart-1',
      block: 'quart-finesses',
      exercises: [
        sheetExercise('e3', 3, block: 'quart-finesses'),
        sheetExercise('e4', 4, block: 'quart-finesses'),
      ],
    );
    expect(resultsRecallBlock(finesse, [...all, finesse]), 'demi-bille');
  });

  test('has no recall block when the whole chain is in one block', () {
    final single = [
      buildSheet(order: 1, previous: null),
      buildSheet(part: 2, order: 2, previous: 'demi-bille-1'),
    ];

    expect(resultsRecallBlock(single.last, single), isNull);
  });

  test('stops quietly on a previous session unknown to the catalogue', () {
    final orphan = buildSheet(order: 2, previous: 'inconnue-9');

    expect(resultsRecallBlock(orphan, [orphan]), isNull);
  });

  test('never loops on a cyclic chain', () {
    final a = buildSheet(order: 2, previous: 'demi-bille-2');
    final b = buildSheet(part: 2, order: 3, previous: 'demi-bille-1');

    expect(resultsRecallBlock(a, [a, b]), isNull);
  });
}
