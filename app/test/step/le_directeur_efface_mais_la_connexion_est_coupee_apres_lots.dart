import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leDirecteurEffaceMaisLaConnexionEstCoupeeApresLots(
  WidgetTester tester,
  String name,
  num lots,
) async {
  final world = OperationsWorld.current;
  world
    ..batchesMark = world.store.appliedBatches
    ..lastErased = name;
  world.store.failAfterBatches = lots.toInt();
  world.erasureResult = await world.erasure.erase(
    OperationsWorld.studentId(name),
  );
}
