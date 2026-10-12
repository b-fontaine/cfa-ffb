import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> laCourbeContientLesPoints(
  WidgetTester tester,
  String points,
) async {
  final actual = TrackingWorld.current.curve.points.map((p) => p.potted);
  expect(actual.join(', '), points);
}
