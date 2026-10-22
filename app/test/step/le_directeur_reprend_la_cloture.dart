import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leDirecteurReprendLaCloture(WidgetTester tester) async {
  final world = OperationsWorld.current;
  world.store
    ..failAfterBatches = null
    ..dropAckAt = null;
  world.closureOutcome(await world.resumeFound());
}
