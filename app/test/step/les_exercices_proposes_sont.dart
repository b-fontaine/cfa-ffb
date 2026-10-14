import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: les exercices proposés sont {'posture 3, posture 4'}
Future<void> lesExercicesProposesSont(
  WidgetTester tester,
  String exercises,
) async {
  expect(TrackingWorld.current.plan.exercises, [
    for (final label in TrackingWorld.names(exercises))
      TrackingWorld.exercise(label),
  ]);
}
