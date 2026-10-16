import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the full screen was entered {1} times
Future<void> theFullScreenWasEnteredTimes(
  WidgetTester tester,
  num count,
) async {
  expect(UiWorld.fullscreen.enterCalls, count);
}
