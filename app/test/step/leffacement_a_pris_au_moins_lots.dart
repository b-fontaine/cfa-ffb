import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leffacementAPrisAuMoinsLots(WidgetTester tester, num lots) async {
  expect(
    OperationsWorld.current.store.appliedBatches,
    greaterThanOrEqualTo(lots.toInt()),
  );
}
