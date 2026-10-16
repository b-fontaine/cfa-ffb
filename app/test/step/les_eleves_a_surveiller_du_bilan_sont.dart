import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: les élèves à surveiller du bilan sont {'Théo, Léa'} (dans cet ordre)
Future<void> lesElevesASurveillerDuBilanSont(
  WidgetTester tester,
  String students,
) async {
  final outcome = TrackingWorld.valueOf(TrackingWorld.current.reviewResult)
      .outcome;
  expect(
    [for (final watched in outcome.watched) watched.studentId],
    [
      for (final name in TrackingWorld.names(students))
        TrackingWorld.studentId(name),
    ],
  );
}
