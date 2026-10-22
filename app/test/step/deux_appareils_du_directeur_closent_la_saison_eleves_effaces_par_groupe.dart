import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> deuxAppareilsDuDirecteurClosentLaSaisonElevesEffacesParGroupe(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world.toErase = world.seeded!.firstOfEach(count.toInt());
  final device = world.actor(uid: world.uid, role: Role.director);
  Future<void> yieldOften() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.value();
    }
  }

  world.store.beforeCommit = yieldOften;
  device.store.beforeCommit = yieldOften;
  world.closureResults = await Future.wait([
    world.close(),
    world.close(by: device.closing),
  ]);
  world.store.beforeCommit = null;
}
