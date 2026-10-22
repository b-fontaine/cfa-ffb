import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void>
leDirecteurClotLaSaisonElevesEffacesParGroupePresenceRetardataireApresLaPurge(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world.toErase = world.seeded!.firstOfEach(count.toInt());
  final late = world.toErase.first;
  final record = world.recordPresenting(late);
  var done = false;
  // La purge est finie quand le marqueur passe à l'étape de reconduction
  // (étape 5) : un autre appareil, en retard, ajoute alors une présence de
  // l'élève marqué (aucune règle ne parcourt une liste pour la refuser).
  world.store.afterCommit = (_) async {
    if (done) return;
    final stage = world.stageOfMarker();
    if (stage == null || stage < 5) return;
    done = true;
    world.addPresence(record, late);
  };
  await world.close();
  world.store.afterCommit = null;
  expect(done, isTrue, reason: 'la purge a été atteinte');
}
