import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> letatDuClubEstCeluiDuneClotureEnUnSeulLotSurDesDepotsEnMemoire(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  final reference = await world.oneShotReference(
    prepareNext: world.prepareNext,
    dropPlanned: world.dropPlanned,
  );
  expect(await world.state(), reference);
}
