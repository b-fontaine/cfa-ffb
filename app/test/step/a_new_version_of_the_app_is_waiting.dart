import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: a new version of the app is waiting
///
/// À placer avant `the app is running` : le navigateur a déjà installé la
/// version, elle attend d'être activée.
Future<void> aNewVersionOfTheAppIsWaiting(WidgetTester tester) async {
  UiWorld.updateWaiting = true;
}
