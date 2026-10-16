import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the full screen was left {1} times
Future<void> theFullScreenWasLeftTimes(WidgetTester tester, num count) async {
  expect(UiWorld.fullscreen.exitCalls, count);
}
