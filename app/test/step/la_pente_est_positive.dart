import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> laPenteEstPositive(WidgetTester tester) async {
  expect(TrackingWorld.current.curve.slope, greaterThan(0));
}
