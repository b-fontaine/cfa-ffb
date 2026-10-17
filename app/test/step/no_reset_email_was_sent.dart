import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: no reset e-mail was sent
///
/// Une adresse inconnue reçoit la même confirmation à l'écran, mais aucun
/// courriel ne part.
Future<void> noResetEmailWasSent(WidgetTester tester) async {
  expect(UiWorld.auth.resetsSent, isEmpty);
}
