import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> unAutreAppareilDuDirecteurReprendLaClotureTrouvee(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  world.store
    ..failAfterBatches = null
    ..dropAckAt = null;
  final device = world.actor(uid: world.uid, role: Role.director);
  world.closureOutcome(await world.resumeFound(by: device.closing));
}
