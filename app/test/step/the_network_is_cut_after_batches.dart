import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

/// Usage: the network is cut after {1} batches
Future<void> theNetworkIsCutAfterBatches(
  WidgetTester tester,
  num batches,
) async {
  ImportWorld.current.store.failAfterBatches = batches.toInt();
}
