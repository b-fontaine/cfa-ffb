import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the account {'coach@example.org'} exists with the password {'secret'}
///
/// Un compte dont l'adresse est vérifiée.
Future<void> theAccountExistsWithThePassword(
  WidgetTester tester,
  String email,
  String password,
) async {
  await UiWorld.prepare(tester);
  UiWorld.auth.seed(email: email, password: password);
}
