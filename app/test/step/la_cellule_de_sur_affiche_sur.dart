import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
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

const Map<String, BlockStatus> _blockStatuses = {
  'à commencer': BlockStatus.notStarted,
  'en cours': BlockStatus.inProgress,
  'terminée': BlockStatus.mastered,
  'acquise au positionnement': BlockStatus.acquiredAtPlacement,
  'à revoir': BlockStatus.toReview,
};

/// Usage: la cellule de {'Léa'} sur {'posture'} affiche {1} sur {4} {'en
///   cours'}
Future<void> laCelluleDeSurAfficheSur(
  WidgetTester tester,
  String student,
  String block,
  num done,
  num total,
  String status,
) async {
  final cell = _gridCell(student, block);
  expect(cell.doneCount, done.toInt());
  expect(cell.total, total.toInt());
  expect(cell.status, _blockStatuses[status]);
}
