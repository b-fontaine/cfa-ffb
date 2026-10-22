import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leDirecteurReprendLeffacementDeLeJourMeme(
  WidgetTester tester,
  String name,
) async {
  final world = OperationsWorld.current;
  world.batchesMark = world.store.appliedBatches;
  world.erasureResult = await world.erasure.erase(
    OperationsWorld.studentId(name),
  );
}
