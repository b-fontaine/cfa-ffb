import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the clubs of the account cannot be read
///
/// Hors ligne : le service d'authentification répond avec la session
/// persistée, mais la lecture des clubs échoue.
Future<void> theClubsOfTheAccountCannotBeRead(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  UiWorld.memberships.unavailable = true;
}
