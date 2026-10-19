import 'package:flutter_test/flutter_test.dart';

import '../support/sync_world.dart';

/// Usage: the server acknowledges the changes
Future<void> theServerAcknowledgesTheChanges(WidgetTester tester) async {
  SyncWorld.acknowledgeAll();
  await tester.pumpAndSettle();
}
