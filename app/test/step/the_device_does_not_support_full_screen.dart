import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the device does not support full screen
///
/// À placer avant `the app is running` (iPhone Safari, bureau natif).
Future<void> theDeviceDoesNotSupportFullScreen(WidgetTester tester) async {
  UiWorld.fullscreenSupported = false;
}
