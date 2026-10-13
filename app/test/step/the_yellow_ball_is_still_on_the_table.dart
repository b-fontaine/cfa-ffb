import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the yellow ball is still on the table
Future<void> theYellowBallIsStillOnTheTable(WidgetTester tester) async {
  expect(DiagramWorld.isPotted(tester, 'y1'), isFalse);
  expect(find.byKey(const ValueKey('ball-y1')), findsOneWidget);
}
