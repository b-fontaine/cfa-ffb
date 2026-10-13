import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the yellow ball is potted
Future<void> theYellowBallIsPotted(WidgetTester tester) async {
  expect(DiagramWorld.isPotted(tester, 'y1'), isTrue);
  // Une bille empochée n'est plus peinte sur la table.
  expect(find.byKey(const ValueKey('ball-y1')), findsNothing);
  expect(find.byType(BilliardBall), findsOneWidget);
}
