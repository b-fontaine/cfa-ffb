import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: no label covers a path, a ball or another label
Future<void> noLabelCoversAPathABallOrAnotherLabel(WidgetTester tester) async {
  // Sans étiquette, rien ne prouve que le schéma est lisible.
  expect(DiagramWorld.labelCount(tester), isPositive);
  expect(DiagramWorld.labelCollisions(tester), isEmpty);
}
