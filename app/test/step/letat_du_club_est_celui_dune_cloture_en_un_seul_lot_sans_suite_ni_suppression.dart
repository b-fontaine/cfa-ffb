import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> letatDuClubEstCeluiDuneClotureEnUnSeulLotSansSuiteNiSuppression(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  final reference = await world.oneShotReference(
    prepareNext: false,
    dropPlanned: false,
  );
  expect(await world.state(), reference);
}
