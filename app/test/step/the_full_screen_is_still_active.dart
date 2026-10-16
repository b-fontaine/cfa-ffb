import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the full screen is still active
Future<void> theFullScreenIsStillActive(WidgetTester tester) async {
  expect(UiWorld.fullscreen.isActive, isTrue);
}
