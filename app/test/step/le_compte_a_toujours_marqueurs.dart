import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> leCompteAToujoursMarqueurs(
  WidgetTester tester,
  String name,
  num count,
) async {
  expect(OwnMarkersWorld.current.markersOf(name), count);
}
