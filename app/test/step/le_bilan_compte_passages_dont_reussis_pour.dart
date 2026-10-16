import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le bilan compte {1} passages dont {1} réussis pour {'posture 1'}
Future<void> leBilanComptePassagesDontReussisPour(
  WidgetTester tester,
  num passes,
  num passed,
  String exercise,
) async {
  final outcome = TrackingWorld.valueOf(TrackingWorld.current.reviewResult)
      .outcome;
  final line = outcome.byExercise.firstWhere(
    (line) => line.exercise == TrackingWorld.exercise(exercise),
    orElse: () => fail('aucun passage pour $exercise'),
  );
  expect((line.passes, line.passed), (passes.toInt(), passed.toInt()));
}
