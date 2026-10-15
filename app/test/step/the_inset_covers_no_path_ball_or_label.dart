import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the inset covers no path, ball or label
Future<void> theInsetCoversNoPathBallOrLabel(WidgetTester tester) async {
  expect(DiagramWorld.insetCollisions(tester), isEmpty);
}
