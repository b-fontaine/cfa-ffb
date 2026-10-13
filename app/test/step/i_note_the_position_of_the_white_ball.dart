import 'package:flutter_test/flutter_test.dart';

import '../support/diagram_world.dart';

/// Usage: I note the position of the white ball
Future<void> iNoteThePositionOfTheWhiteBall(WidgetTester tester) async {
  DiagramWorld.noted = DiagramWorld.position(tester, 'w');
}
