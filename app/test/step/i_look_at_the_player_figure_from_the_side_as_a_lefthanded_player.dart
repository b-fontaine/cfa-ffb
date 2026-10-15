import 'package:billard_cfa/shared/ui/player_figure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the player figure from the side as a left-handed player
Future<void> iLookAtThePlayerFigureFromTheSideAsALefthandedPlayer(
  WidgetTester tester,
) => DiagramWorld.show(
  tester,
  const PlayerFigure(
    focus: [PlayerMark.feet, PlayerMark.legsAndHips],
    handedness: Handedness.left,
  ),
);
