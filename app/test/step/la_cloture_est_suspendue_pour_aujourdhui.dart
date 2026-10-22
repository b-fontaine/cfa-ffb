import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laClotureEstSuspenduePourAujourdhui(WidgetTester tester) async {
  expect(
    OperationsWorld.current.closureOutcome().status,
    OperationRunStatus.paused,
  );
}
