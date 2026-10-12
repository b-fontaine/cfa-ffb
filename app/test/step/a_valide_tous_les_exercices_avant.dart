import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> aValideTousLesExercicesAvant(
  WidgetTester tester,
  String student,
  String exercise,
) async {
  await TrackingWorld.current.seedValidatedBefore([
    student,
  ], TrackingWorld.exercise(exercise));
}
