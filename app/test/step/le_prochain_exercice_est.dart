import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le prochain exercice est {'puissance 2'}
Future<void> leProchainExerciceEst(WidgetTester tester, String exercise) async {
  expect(
    TrackingWorld.current.sheet.header.next,
    TrackingWorld.exercise(exercise),
  );
}
