import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'exercice en cours est {'posture 2'}
Future<void> lexerciceEnCoursEst(WidgetTester tester, String exercise) async {
  expect(
    TrackingWorld.current.sheet.header.current,
    TrackingWorld.exercise(exercise),
  );
}
