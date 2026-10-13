import 'dart:math' as math;

import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the ghost ball touches the object ball
Future<void> theGhostBallTouchesTheObjectBall(WidgetTester tester) async {
  final spec = tester.widget<TableDiagram>(find.byType(TableDiagram)).spec;
  final object = spec.balls.singleWhere((b) => b.color == BallKind.red);
  final ghost = spec.ghosts.singleWhere(
    (g) => g.role == DiagramGhostRole.impact,
  );
  final distance = math.sqrt(
    math.pow(ghost.at.x - object.at.x, 2) +
        math.pow(ghost.at.y - object.at.y, 2),
  );

  // Blanche (24,0 mm) + bille de but (25,4 mm) : 49,4 / 231,25 = 0,213622 case,
  // et non 2 x 25,4 / 231,25 = 0,219676.
  expect(distance, closeTo(0.213622, 1e-6));
  expect(distance, lessThan(0.219676));
}
