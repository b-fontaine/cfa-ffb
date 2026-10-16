import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the device supports full screen
///
/// À placer avant `the app is running`.
Future<void> theDeviceSupportsFullScreen(WidgetTester tester) async {
  UiWorld.fullscreenSupported = true;
}
