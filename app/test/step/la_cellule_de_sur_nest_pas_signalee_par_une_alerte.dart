import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

GridRow _gridRow(String blockId) => TrackingWorld.current.grid.rows.firstWhere(
  (row) => row.technique.blockId == blockId,
  orElse: () => fail('technique inconnue : $blockId'),
);

GridCell _gridCell(String student, String blockId) =>
    _gridRow(blockId).cells.firstWhere(
      (cell) => cell.studentId == TrackingWorld.studentId(student),
      orElse: () => fail("$student n'est pas une colonne"),
    );

/// Usage: la cellule de {'Léa'} sur {'posture'} n'est pas signalée par une
///   alerte
Future<void> laCelluleDeSurNestPasSignaleeParUneAlerte(
  WidgetTester tester,
  String student,
  String block,
) async {
  expect(_gridCell(student, block).alerted, isFalse);
}
