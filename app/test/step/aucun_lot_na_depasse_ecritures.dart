import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> aucunLotNaDepasseEcritures(WidgetTester tester, num limit) async {
  final log = OperationsWorld.current.store.log;
  expect(log, isNotEmpty);
  for (final batch in log) {
    expect(batch.length, lessThanOrEqualTo(limit.toInt()));
  }
}
