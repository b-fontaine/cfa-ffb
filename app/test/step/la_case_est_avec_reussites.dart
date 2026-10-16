import 'package:billard_cfa/entities/exercise_result/domain/exercise_cell.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

const Map<String, ExerciseCellState> _cellStates = {
  'à faire': ExerciseCellState.todo,
  'en cours': ExerciseCellState.inProgress,
  'validée': ExerciseCellState.validated,
  'acquise': ExerciseCellState.acquired,
};

ExerciseCell _cell(String exercise) {
  final ref = TrackingWorld.exercise(exercise);
  final row = TrackingWorld.current.sheet.path.firstWhere(
    (row) => row.blockId == ref.blockId,
  );
  return row.summary.cells.firstWhere((cell) => cell.exercise == ref);
}

/// Usage: la case {'posture 2'} est {'en cours'} avec {2} réussites
Future<void> laCaseEstAvecReussites(
  WidgetTester tester,
  String exercise,
  String state,
  num passed,
) async {
  final cell = _cell(exercise);
  expect(cell.state, _cellStates[state]);
  expect(cell.passedCount, passed.toInt());
}
