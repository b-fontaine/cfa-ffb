import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Léa'} a validé {'posture 1'} grâce à cette séance
Future<void> aValideGraceACetteSeance(
  WidgetTester tester,
  String student,
  String exercise,
) async {
  final outcome = TrackingWorld.valueOf(TrackingWorld.current.reviewResult)
      .outcome;
  expect(
    [for (final v in outcome.validations) (v.studentId, v.exercise)],
    contains((
      TrackingWorld.studentId(student),
      TrackingWorld.exercise(exercise),
    )),
  );
}
