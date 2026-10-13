import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the white ball is at the start of the shot
Future<void> theWhiteBallIsAtTheStartOfTheShot(WidgetTester tester) async {
  expect(DiagramWorld.position(tester, 'w'), DiagramWorld.start('w'));
}
