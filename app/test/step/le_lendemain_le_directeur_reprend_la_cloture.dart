import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leLendemainLeDirecteurReprendLaCloture(WidgetTester tester) async {
  final world = OperationsWorld.current..clock.advance(const Duration(days: 1));
  world.closureOutcome(await world.resumeFound());
}
