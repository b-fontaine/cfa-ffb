import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leDirecteurReprendLeffacementDe(
  WidgetTester tester,
  String name,
) async {
  final world = OperationsWorld.current;
  world.store
    ..failAfterBatches = null
    ..dropAckAt = null;
  final result = await world.erasure.erase(OperationsWorld.studentId(name));
  world.erasureResult = result;
  expect(world.erasureOutcome().status, OperationRunStatus.completed);
}
