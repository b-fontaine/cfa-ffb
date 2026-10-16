import 'package:billard_cfa/entities/exercise_result/domain/exercise_cell.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

ShowcaseRow _showcaseRow(String blockTitleKey) {
  final catalogue = TrackingWorld.current.catalogue;
  final block = catalogue.blockById(blockTitleKey)!;
  return TrackingWorld.current.showcase.rows.firstWhere(
    (row) => row.title == block.title,
  );
}

const Map<String, ExerciseCellState> _cellStates = {
  'à faire': ExerciseCellState.todo,
  'en cours': ExerciseCellState.inProgress,
  'validée': ExerciseCellState.validated,
  'acquise': ExerciseCellState.acquired,
};

/// Usage: la case {'posture 1'} de la vue élève est {'en cours'}
Future<void> laCaseDeLaVueEleveEst(
  WidgetTester tester,
  String exercise,
  String state,
) async {
  final ref = TrackingWorld.exercise(exercise);
  final row = _showcaseRow(ref.blockId);
  expect(row.cells[ref.number - 1].state, _cellStates[state]);
}
