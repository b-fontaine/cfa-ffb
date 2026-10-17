import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'coach@example.org'} is signed in on the device
///
/// Session persistée du SDK : le compte est déjà connecté à l'ouverture.
Future<void> isSignedInOnTheDevice(WidgetTester tester, String email) async {
  await UiWorld.prepare(tester);
  UiWorld.auth.restoreSession(email);
}
