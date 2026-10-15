import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I see {7} diagram labels
Future<void> iSeeDiagramLabels(WidgetTester tester, num count) async {
  expect(DiagramWorld.labelCount(tester), count);
}
