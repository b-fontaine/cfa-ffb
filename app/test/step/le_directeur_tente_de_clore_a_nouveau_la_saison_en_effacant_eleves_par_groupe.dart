import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leDirecteurTenteDeCloreANouveauLaSaisonEnEffacantElevesParGroupe(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world.batchesMark = world.store.appliedBatches;
  // D'autres choix que ceux du marqueur : `toErase` du monde reste ceux de la
  // première clôture (la référence « un seul lot » en dépend).
  world.closureResult = await world.closing.close(
    seasonId: OperationsWorld.seasonId,
    closedOn: OperationsWorld.day,
    erase: world.seeded!.firstOfEach(count.toInt()),
    prepareNext: world.prepareNext,
    dropPlanned: world.dropPlanned,
  );
}
