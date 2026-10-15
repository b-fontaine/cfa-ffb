import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the inset covers nothing on every catalogue diagram
Future<void> theInsetCoversNothingOnEveryCatalogueDiagram(
  WidgetTester tester,
) async {
  var count = 0;
  final problems = await DiagramWorld.catalogueProblems(
    tester,
    (tester) => DiagramWorld.insetRect(tester) == null
        ? const []
        : DiagramWorld.insetCollisions(tester),
    onCount: (n) => count = n,
  );
  expect(count, greaterThan(100));
  expect(problems, isEmpty);
}
