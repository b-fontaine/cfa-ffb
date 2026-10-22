import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> unCompteEleveEstLieA(WidgetTester tester, String name) async {
  await OperationsWorld.current.seeding(
    (w) async => w.seedStudentAccount(name),
  );
}
