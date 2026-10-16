import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le parcours est à commencer
Future<void> leParcoursEstACommencer(WidgetTester tester) async {
  expect(TrackingWorld.current.sheet.header.toStart, isTrue);
}
