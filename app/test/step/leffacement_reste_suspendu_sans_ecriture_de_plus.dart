import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leffacementResteSuspenduSansEcritureDePlus(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  expect(world.erasureOutcome().status, OperationRunStatus.paused);
  expect(world.store.appliedBatches, world.batchesMark);
}
