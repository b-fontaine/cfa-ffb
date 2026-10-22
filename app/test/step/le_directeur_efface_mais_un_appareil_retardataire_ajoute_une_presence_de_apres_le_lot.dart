import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void>
leDirecteurEffaceMaisUnAppareilRetardataireAjouteUnePresenceDeApresLeLot(
  WidgetTester tester,
  String name,
  String late,
  num lot,
) async {
  final world = OperationsWorld.current;
  world
    ..batchesMark = world.store.appliedBatches
    ..lastErased = name;
  // L'autre appareil écrit sans règle ni coupure : une présence que les règles
  // ne peuvent pas refuser (une règle ne parcourt pas une liste).
  world.store.afterCommit = (applied) async {
    if (applied != lot.toInt()) return;
    world.addPresence(
      world.firstRecord[late]!,
      OperationsWorld.studentId(late),
    );
  };
  world.erasureResult = await world.erasure.erase(
    OperationsWorld.studentId(name),
  );
  world.store.afterCommit = null;
}
