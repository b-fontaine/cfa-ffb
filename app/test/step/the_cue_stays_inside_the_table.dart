import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the cue stays inside the table
Future<void> theCueStaysInsideTheTable(WidgetTester tester) async {
  expect(DiagramWorld.cueIsInsideTable(tester), isTrue);
}
