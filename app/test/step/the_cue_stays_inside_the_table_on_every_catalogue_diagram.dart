import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the cue stays inside the table on every catalogue diagram
Future<void> theCueStaysInsideTheTableOnEveryCatalogueDiagram(
  WidgetTester tester,
) async {
  expect(await DiagramWorld.cuesOutsideTheTable(tester), isEmpty);
}
