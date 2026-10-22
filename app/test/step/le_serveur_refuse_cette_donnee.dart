import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leServeurRefuseCetteDonnee(WidgetTester tester) async {
  final world = OperationsWorld.current;
  expect(world.lastWriteRefused, isTrue);
  expect(world.doc('clubs/c1/attempts/retardataire'), isNull);
}
