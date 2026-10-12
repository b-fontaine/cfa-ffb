import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lePremierExerciceEst(WidgetTester tester, String exercise) async {
  expect(
    TrackingWorld.current.plan.exercises.first,
    TrackingWorld.exercise(exercise),
  );
}
