import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> lesDeuxCloturesSontTerminees(WidgetTester tester) async {
  final world = OperationsWorld.current;
  expect(world.closureResults, hasLength(2));
  for (final result in world.closureResults) {
    final outcome = world.closureOutcome(result);
    expect(
      outcome.status,
      OperationRunStatus.completed,
      reason: '${outcome.failure}',
    );
  }
}
