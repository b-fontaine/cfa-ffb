import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> leCompteGardeMarqueursDansLeClub(
  WidgetTester tester,
  String name,
  num count,
) async {
  expect(StaleMarkersWorld.current.markersOf(name), count.toInt());
}
