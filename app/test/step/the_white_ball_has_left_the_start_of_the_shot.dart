import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the white ball has left the start of the shot
Future<void> theWhiteBallHasLeftTheStartOfTheShot(WidgetTester tester) async {
  expect(DiagramWorld.position(tester, 'w'), isNot(DiagramWorld.start('w')));
}
