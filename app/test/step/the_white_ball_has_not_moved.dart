import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: the white ball has not moved
Future<void> theWhiteBallHasNotMoved(WidgetTester tester) async {
  expect(DiagramWorld.position(tester, 'w'), DiagramWorld.noted);
}
