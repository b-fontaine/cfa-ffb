import 'package:billard_cfa/entities/exercise_result/domain/exercise_cell.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

ExerciseCell _cell(String exercise) {
  final ref = TrackingWorld.exercise(exercise);
  final row = TrackingWorld.current.sheet.path.firstWhere(
    (row) => row.blockId == ref.blockId,
  );
  return row.summary.cells.firstWhere((cell) => cell.exercise == ref);
}

/// Usage: la case {'posture 1'} est signalée par une alerte
Future<void> laCaseEstSignaleeParUneAlerte(
  WidgetTester tester,
  String exercise,
) async {
  expect(_cell(exercise).alerted, isTrue);
}
