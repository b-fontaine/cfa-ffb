import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Usage: the device theme is {'dark'}
Future<void> theDeviceThemeIs(WidgetTester tester, String theme) async {
  tester.platformDispatcher.platformBrightnessTestValue = switch (theme) {
    'dark' => Brightness.dark,
    _ => Brightness.light,
  };
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}
