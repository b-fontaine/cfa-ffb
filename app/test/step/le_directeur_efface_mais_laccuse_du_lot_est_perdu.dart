import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leDirecteurEffaceMaisLaccuseDuLotEstPerdu(
  WidgetTester tester,
  String name,
  num lot,
) async {
  final world = OperationsWorld.current;
  world
    ..batchesMark = world.store.appliedBatches
    ..lastErased = name;
  world.store.dropAckAt = lot.toInt() - 1;
  world.erasureResult = await world.erasure.erase(
    OperationsWorld.studentId(name),
  );
}
