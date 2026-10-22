import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> lePlafondDecrituresDuneOperationEstDeParJour(
  WidgetTester tester,
  num writes,
) async {
  final world = OperationsWorld.current;
  world.runner = OperationRunner(
    world.operationStore,
    world.ledger,
    limits: OperationLimits(dailyWrites: writes.toInt()),
  );
}
