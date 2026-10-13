import 'package:billard_cfa/shared/ui/player_figure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I look at the player figure from the side
Future<void> iLookAtThePlayerFigureFromTheSide(WidgetTester tester) =>
    DiagramWorld.show(tester, const PlayerFigure());
