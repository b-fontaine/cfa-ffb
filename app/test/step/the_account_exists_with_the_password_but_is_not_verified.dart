import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the account {'new@example.org'} exists with the password {'secret'}
/// but is not verified
Future<void> theAccountExistsWithThePasswordButIsNotVerified(
  WidgetTester tester,
  String email,
  String password,
) async {
  await UiWorld.prepare(tester);
  UiWorld.auth.seed(email: email, password: password, emailVerified: false);
}
