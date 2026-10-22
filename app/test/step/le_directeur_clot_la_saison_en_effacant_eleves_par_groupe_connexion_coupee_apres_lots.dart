import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void>
leDirecteurClotLaSaisonEnEffacantElevesParGroupeConnexionCoupeeApresLots(
  WidgetTester tester,
  num count,
  num lots,
) async {
  final world = OperationsWorld.current;
  world.toErase = world.seeded!.firstOfEach(count.toInt());
  world.store.failAfterBatches = lots.toInt();
  await world.close();
}
