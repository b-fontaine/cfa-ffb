import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the ghost circle is not hidden by the arrow head
Future<void> theGhostCircleIsNotHiddenByTheArrowHead(
  WidgetTester tester,
) async {
  final spec = tester.widget<TableDiagram>(find.byType(TableDiagram)).spec;
  final ghost = spec.ghosts.singleWhere(
    (g) => g.role == DiagramGhostRole.impact,
  );
  final aim = spec.arrows.singleWhere((a) => a.kind == DiagramArrowKind.aim);
  final geometry = DiagramWorld.geometry(tester);
  final points = TableDiagram.arrowPixelPoints(spec, aim, geometry);
  final center = geometry.toPixel(Offset(ghost.at.x, ghost.at.y));

  // La pointe s'arrête sur le cercle : elle ne le recouvre pas.
  expect((points.last - center).distance, closeTo(geometry.ghostRadiusPx, 0.5));
}
