import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I see the ball quantity inset under the table
Future<void> iSeeTheBallQuantityInsetUnderTheTable(WidgetTester tester) async {
  expect(DiagramWorld.insetRect(tester), isNotNull);
  expect(DiagramWorld.insetIsBelowTheTable(tester), isTrue);
}
