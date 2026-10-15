import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I see the ball quantity inset
Future<void> iSeeTheBallQuantityInset(WidgetTester tester) async {
  expect(DiagramWorld.insetRect(tester), isNotNull);
}
