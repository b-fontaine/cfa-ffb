import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> laDureeDeLaSeanceEstDeMinutes(
  WidgetTester tester,
  num minutes,
) async {
  expect(TrackingWorld.current.plan.durationMinutes, minutes);
}
