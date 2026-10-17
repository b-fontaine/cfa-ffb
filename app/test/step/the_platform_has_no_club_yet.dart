import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the platform has no club yet
///
/// Ni club, ni member, ni administrateur côté serveur (les comptes d'accès
/// restent).
Future<void> thePlatformHasNoClubYet(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  UiWorld.memberships.clear();
}
