import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: les présents sans passage sont {'Théo'}
Future<void> lesPresentsSansPassageSont(
  WidgetTester tester,
  String students,
) async {
  final outcome = TrackingWorld.valueOf(TrackingWorld.current.reviewResult)
      .outcome;
  expect(outcome.unrated.map((id) => id.value).toSet(), {
    for (final name in TrackingWorld.names(students))
      TrackingWorld.studentId(name).value,
  });
}
