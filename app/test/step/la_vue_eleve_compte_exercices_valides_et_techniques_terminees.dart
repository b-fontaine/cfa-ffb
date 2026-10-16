import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la vue élève compte {4} exercices validés et {1} techniques terminées
Future<void> laVueEleveCompteExercicesValidesEtTechniquesTerminees(
  WidgetTester tester,
  num validated,
  num finished,
) async {
  final showcase = TrackingWorld.current.showcase;
  expect(showcase.validatedCount, validated.toInt());
  expect(showcase.finishedTechniques, finished.toInt());
}
