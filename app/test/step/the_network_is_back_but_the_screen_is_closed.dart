import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';
import '../support/import_world.dart';

/// Usage: the network is back but the screen is closed
Future<void> theNetworkIsBackButTheScreenIsClosed(WidgetTester tester) async {
  await ImportScreenWorld.close(tester);
  ImportWorld.current.store.failAfterBatches = null;
}
