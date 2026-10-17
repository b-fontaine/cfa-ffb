import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: nobody is signed in on the device
///
/// Ni session persistée, ni compte par défaut : l'appareil s'ouvre sur la
/// connexion.
Future<void> nobodyIsSignedInOnTheDevice(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  await UiWorld.auth.signOut();
}
