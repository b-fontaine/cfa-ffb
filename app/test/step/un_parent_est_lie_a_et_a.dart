import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> unParentEstLieAEtA(
  WidgetTester tester,
  String name,
  String other,
) async {
  await OperationsWorld.current.seeding(
    (w) async => w.seedGuardian(name, also: [other]),
  );
}
