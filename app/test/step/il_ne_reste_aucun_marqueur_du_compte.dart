import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> ilNeResteAucunMarqueurDuCompte(
  WidgetTester tester,
  String name,
) async {
  expect(OwnMarkersWorld.current.markersOf(name), 0);
}
