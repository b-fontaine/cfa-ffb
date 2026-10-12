import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lexerciceEstValide(WidgetTester tester, String exercise) async {
  final recorded = TrackingWorld.valueOf(TrackingWorld.current.lastRecord);
  expect(recorded.attempt.exercise, TrackingWorld.exercise(exercise));
  expect(recorded.result.isValidated, isTrue);
}
