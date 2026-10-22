import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leffacementDeCetEleveEstTermine(WidgetTester tester) async {
  final world = OperationsWorld.current;
  expect(
    world.erasureOutcome(world.adminErasure).status,
    OperationRunStatus.completed,
  );
}
