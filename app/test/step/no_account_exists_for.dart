import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: no account exists for {'new@example.org'}
Future<void> noAccountExistsFor(WidgetTester tester, String email) async {
  expect(UiWorld.auth.accountOf(email), isNull);
}
