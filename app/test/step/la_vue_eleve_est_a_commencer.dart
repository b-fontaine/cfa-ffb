import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la vue élève est à commencer
Future<void> laVueEleveEstACommencer(WidgetTester tester) async {
  expect(TrackingWorld.current.showcase.toStart, isTrue);
}
