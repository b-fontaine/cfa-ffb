import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the diagram is described as {'Half ball; Tip at the centre'}
Future<void> theDiagramIsDescribedAs(
  WidgetTester tester,
  String description,
) async {
  expect(DiagramWorld.describedAs(description), findsOneWidget);
}
