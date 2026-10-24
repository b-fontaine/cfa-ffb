import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> ilResteMarqueursDansLautreClub(
  WidgetTester tester,
  num count,
) async {
  expect(
    StaleMarkersWorld.current.markersOf('parti', inClub: 'c2'),
    count.toInt(),
  );
}
