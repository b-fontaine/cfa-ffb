import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laClotureEstTerminee(WidgetTester tester) async {
  final outcome = OperationsWorld.current.closureOutcome();
  expect(
    outcome.status,
    OperationRunStatus.completed,
    reason: '${outcome.failure}',
  );
}
