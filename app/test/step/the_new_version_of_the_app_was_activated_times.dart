import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the new version of the app was activated {1} times
Future<void> theNewVersionOfTheAppWasActivatedTimes(
  WidgetTester tester,
  num count,
) async {
  expect(UiWorld.appUpdate.applyCalls, count);
}
