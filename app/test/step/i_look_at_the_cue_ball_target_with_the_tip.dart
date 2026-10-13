import 'package:billard_cfa/shared/ui/cue_ball_target.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the cue ball target with the tip {'bottom'}
Future<void> iLookAtTheCueBallTargetWithTheTip(
  WidgetTester tester,
  String tip,
) {
  final point = switch (tip) {
    'center' => TipPoint.center,
    'top' => TipPoint.top,
    'bottom' => TipPoint.bottom,
    'left' => TipPoint.left,
    'right' => TipPoint.right,
    _ => throw ArgumentError('point du procédé inconnu : $tip'),
  };
  return DiagramWorld.show(tester, CueBallTarget(tipPoint: point));
}
