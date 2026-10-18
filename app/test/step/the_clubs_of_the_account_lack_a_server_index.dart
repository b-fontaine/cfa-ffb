import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the clubs of the account lack a server index
///
/// La requête de groupe exige un index non déployé (`failed-precondition`).
Future<void> theClubsOfTheAccountLackAServerIndex(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  UiWorld.memberships.missingIndex = true;
}
