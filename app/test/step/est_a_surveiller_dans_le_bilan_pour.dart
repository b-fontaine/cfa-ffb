import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Théo'} est à surveiller dans le bilan pour {'posture 1'}
Future<void> estASurveillerDansLeBilanPour(
  WidgetTester tester,
  String student,
  String exercise,
) async {
  final outcome = TrackingWorld.valueOf(TrackingWorld.current.reviewResult)
      .outcome;
  expect(
    [for (final w in outcome.watched) (w.studentId, w.exercise)],
    [(TrackingWorld.studentId(student), TrackingWorld.exercise(exercise))],
  );
}
