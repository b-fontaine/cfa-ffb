import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laClotureAEcritPlusDeEcritures(
  WidgetTester tester,
  num writes,
) async {
  expect(
    OperationsWorld.current.store.appliedWrites,
    greaterThan(writes.toInt()),
  );
}
