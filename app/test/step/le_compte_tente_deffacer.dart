import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leCompteTenteDeffacer(WidgetTester tester, String name) async {
  final world = OperationsWorld.current;
  world
    ..batchesMark = world.store.appliedBatches
    ..lastErased = name;
  world.erasureResult = await world.erasure.erase(
    OperationsWorld.studentId(name),
  );
}
