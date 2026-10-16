import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le parcours n'est pas à commencer
Future<void> leParcoursNestPasACommencer(WidgetTester tester) async {
  expect(TrackingWorld.current.sheet.header.toStart, isFalse);
}
