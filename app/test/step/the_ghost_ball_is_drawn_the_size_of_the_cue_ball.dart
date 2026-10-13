import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the ghost ball is drawn the size of the cue ball
Future<void> theGhostBallIsDrawnTheSizeOfTheCueBall(WidgetTester tester) async {
  // Géométrie du rendu : celle que la peinture du diagramme utilise pour le
  // cercle fantôme (`ghostRadiusPx`) et pour chaque bille (`radiusPxOf`), sur
  // la taille réellement affichée.
  final size = tester.getSize(find.byType(TableDiagram));
  final geometry = TableGeometry.fitting(size);
  final ghost = geometry.ghostRadiusPx;
  final white = geometry.radiusPxOf(BallKind.white);
  final red = geometry.radiusPxOf(BallKind.red);

  expect(size.width, greaterThan(0));
  expect(ghost / white, closeTo(1, 1e-9));
  expect(ghost, lessThan(red));
  expect(ghost / red, closeTo(0.945, 0.001));
}
