import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the clubs of the account are refused by the server
///
/// Les règles refusent la lecture des clubs (`permission-denied`).
Future<void> theClubsOfTheAccountAreRefusedByTheServer(
  WidgetTester tester,
) async {
  await UiWorld.prepare(tester);
  UiWorld.memberships.denied = true;
}
