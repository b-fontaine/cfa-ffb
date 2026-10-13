import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:billard_cfa/shared/ui/ghost_aim_diagram.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the ghost aim towards the pocket {'top right'}
Future<void> iLookAtTheGhostAimTowardsThePocket(
  WidgetTester tester,
  String pocket,
) {
  final target = switch (pocket) {
    'top right' => TablePocket.tr,
    'top middle' => TablePocket.tm,
    'bottom middle' => TablePocket.bm,
    _ => throw ArgumentError('poche inconnue : $pocket'),
  };
  return DiagramWorld.show(
    tester,
    GhostAimDiagram(
      cue: const math.Point(1.84, 2.26),
      object: const math.Point(5, 2),
      pocket: target,
      fraction: ContactFraction.half,
    ),
  );
}
