import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> ontValideTousLesExercicesAvant(
  WidgetTester tester,
  String students,
  String exercise,
) async {
  await TrackingWorld.current.seedValidatedBefore(
    TrackingWorld.names(students),
    TrackingWorld.exercise(exercise),
  );
}
