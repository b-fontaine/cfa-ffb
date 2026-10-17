import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: a verification e-mail was sent to {'new@example.org'}
Future<void> aVerificationEmailWasSentTo(
  WidgetTester tester,
  String email,
) async {
  expect(UiWorld.auth.verificationsSent, contains(email));
}
