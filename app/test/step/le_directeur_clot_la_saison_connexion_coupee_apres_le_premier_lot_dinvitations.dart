import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void>
leDirecteurClotLaSaisonConnexionCoupeeApresLePremierLotDinvitations(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current..toErase = const {};
  world.store.afterCommit = (applied) async {
    if (world.store.log.last.any((path) => path.startsWith('invitations/'))) {
      world.store
        ..failAfterBatches = applied
        ..afterCommit = null;
    }
  };
  await world.close();
}
