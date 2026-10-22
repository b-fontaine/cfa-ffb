import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> unParentEstLieA(WidgetTester tester, String name) async {
  await OperationsWorld.current.seeding((w) async => w.seedGuardian(name));
}
