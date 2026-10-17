import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Usage: the device language changes to {'fr'}
///
/// Change la langue de l'appareil alors que l'écran est déjà ouvert.
Future<void> theDeviceLanguageChangesTo(
  WidgetTester tester,
  String language,
) async {
  tester.platformDispatcher.localesTestValue = [Locale(language)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpAndSettle();
}
