import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> aucunMarqueurDoperationNeReste(WidgetTester tester) async {
  expect(OperationsWorld.current.markers(), isEmpty);
}
