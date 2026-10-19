import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the device is no longer a member of the club
///
/// Le directeur retire le compte de l'appareil du club : les règles du serveur
/// ne lui laissent plus rien lire (document `members` supprimé). Le double du
/// serveur ferme alors, en `permission-denied`, les écoutes ouvertes dans le
/// club, comme l'écoute d'un SDK dont les règles ont changé.
Future<void> theDeviceIsNoLongerAMemberOfTheClub(WidgetTester tester) async {
  UiWorld.documents.revoke(
    'clubs/${UiWorld.clubIdOf(UiWorld.defaultClub).value}/',
  );
  await UiWorld.settle(tester);
}
