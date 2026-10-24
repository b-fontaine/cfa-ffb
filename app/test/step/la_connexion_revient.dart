import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> laConnexionRevient(WidgetTester tester) async {
  final world = OwnMarkersWorld.current;
  world.rules.failAfterBatches = null;
  world.server.failing = null;
}
