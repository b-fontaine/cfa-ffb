import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leDirecteurEtUnAdministrateurClosentLaSaisonElevesEffacesParGroupe(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world.toErase = world.seeded!.firstOfEach(count.toInt());
  final admin = world.actor(uid: 'u-admin', role: Role.admin);
  Future<void> yieldOften() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.value();
    }
  }

  world.store.beforeCommit = yieldOften;
  admin.store.beforeCommit = yieldOften;
  world.closureResults = await Future.wait([
    world.close(),
    world.close(by: admin.closing),
  ]);
  world.store.beforeCommit = null;
}
