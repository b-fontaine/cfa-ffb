import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> unAdministrateurClotLaSaisonElevesEffacesParGroupe(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world.toErase = world.seeded!.firstOfEach(count.toInt());
  final admin = world.actor(uid: 'u-admin', role: Role.admin);
  final outcome = world.closureOutcome(await world.close(by: admin.closing));
  expect(outcome.failure, isNull);
}
