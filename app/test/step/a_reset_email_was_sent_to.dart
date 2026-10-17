import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: a reset e-mail was sent to {'coach@example.org'}
Future<void> aResetEmailWasSentTo(WidgetTester tester, String email) async {
  expect(UiWorld.auth.resetsSent, contains(email));
}
