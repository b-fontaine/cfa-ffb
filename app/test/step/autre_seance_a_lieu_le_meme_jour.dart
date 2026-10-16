import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {1} autre séance a lieu le même jour
Future<void> autreSeanceALieuLeMemeJour(WidgetTester tester, num count) async {
  expect(TrackingWorld.current.upcoming.sameDayOthers, count.toInt());
}
