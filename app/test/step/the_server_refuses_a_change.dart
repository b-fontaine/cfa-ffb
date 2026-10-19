import 'package:flutter_test/flutter_test.dart';

import '../support/sync_world.dart';

/// Usage: the server refuses a change
///
/// Un refus tardif des règles : le SDK annule la modification de son cache.
Future<void> theServerRefusesAChange(WidgetTester tester) async {
  SyncWorld.refuseChange();
  await tester.pumpAndSettle();
}
