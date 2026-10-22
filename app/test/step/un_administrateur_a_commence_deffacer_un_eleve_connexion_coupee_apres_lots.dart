import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> unAdministrateurACommenceDeffacerUnEleveConnexionCoupeeApresLots(
  WidgetTester tester,
  num lots,
) async {
  final world = OperationsWorld.current;
  final admin = world.actor(uid: 'u-admin', role: Role.admin);
  final id = world.seeded!.firstOfEach(1).first;
  admin.store.failAfterBatches = lots.toInt();
  world
    ..admin = admin
    ..adminErased = id;
  await admin.erasure.erase(id);
  admin.store.failAfterBatches = null;
  expect(world.doc('clubs/c1/students/${id.value}')!['erasing'], isTrue);
}
