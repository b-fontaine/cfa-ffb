import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/ui/ghost_aim_diagram.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the ghost ball aim in half ball to the top right pocket
Future<void> iLookAtTheGhostBallAimInHalfBallToTheTopRightPocket(
  WidgetTester tester,
) => DiagramWorld.show(
  tester,
  const GhostAimDiagram(
    cue: math.Point(1.84, 2.26),
    object: math.Point(5, 2),
    pocket: TablePocket.tr,
    fraction: ContactFraction.half,
  ),
);
