import 'package:flutter_test/flutter_test.dart';

import '../support/sync_world.dart';

/// Usage: a change waits to be sent to the server
///
/// Une écriture validée localement (hors ligne) : le serveur ne l'a pas
/// encore acquittée.
Future<void> aChangeWaitsToBeSentToTheServer(WidgetTester tester) async {
  SyncWorld.queueChange();
  await tester.pumpAndSettle();
}
