import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leLendemainLeDirecteurReprendLeffacementDe(
  WidgetTester tester,
  String name,
) async {
  final world = OperationsWorld.current..clock.advance(const Duration(days: 1));
  final result = await world.erasure.erase(OperationsWorld.studentId(name));
  world.erasureResult = result;
  expect(world.erasureOutcome().status, OperationRunStatus.completed);
}
