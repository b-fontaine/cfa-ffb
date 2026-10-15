import 'package:billard_cfa/shared/lib/cue_side_geometry.dart';
import 'package:billard_cfa/shared/ui/cue_ball_target.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the cue ball target with the tip {'top'} slightly off
/// centre
Future<void> iLookAtTheCueBallTargetWithTheTipSlightlyOffCentre(
  WidgetTester tester,
  String tip,
) {
  final point = switch (tip) {
    'top' => TipPoint.top,
    'bottom' => TipPoint.bottom,
    'left' => TipPoint.left,
    'right' => TipPoint.right,
    _ => throw ArgumentError('point du procédé inconnu : $tip'),
  };
  return DiagramWorld.show(
    tester,
    CueBallTarget(tipPoint: point, offset: TipOffset.slight),
  );
}
