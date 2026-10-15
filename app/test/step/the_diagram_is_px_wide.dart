import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the diagram is {310} px wide
Future<void> theDiagramIsPxWide(WidgetTester tester, num width) async {
  DiagramWorld.width = width.toDouble();
  addTearDown(() => DiagramWorld.width = DiagramWorld.defaultWidth);
}
