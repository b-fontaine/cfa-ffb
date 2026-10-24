import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> marqueursOntEteRetires(WidgetTester tester, num count) async {
  final world = OwnMarkersWorld.current;
  expect(world.failure, isNull);
  expect(world.removed, count);
}
