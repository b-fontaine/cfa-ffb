import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> aucuneEcritureNaEteFaiteParLeSecondEffacement(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  expect(world.store.appliedBatches, world.batchesMark);
}
