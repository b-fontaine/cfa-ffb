import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I do not see the ball quantity inset
Future<void> iDoNotSeeTheBallQuantityInset(WidgetTester tester) async {
  expect(DiagramWorld.insetRect(tester), isNull);
}
