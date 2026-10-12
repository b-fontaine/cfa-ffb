import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Usage: the device language is {'fr'}
Future<void> theDeviceLanguageIs(WidgetTester tester, String language) async {
  tester.platformDispatcher.localesTestValue = [Locale(language)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}
