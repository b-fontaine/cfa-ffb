import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: an account exists for {'new@example.org'}
Future<void> anAccountExistsFor(WidgetTester tester, String email) async {
  expect(UiWorld.auth.accountOf(email), isNotNull);
}
