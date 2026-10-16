import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le bilan compte {1} passages dont {1} réussis
Future<void> leBilanComptePassagesDontReussis(
  WidgetTester tester,
  num passes,
  num passed,
) async {
  final outcome = TrackingWorld.valueOf(TrackingWorld.current.reviewResult)
      .outcome;
  expect(
    (outcome.totalPasses, outcome.totalPassed),
    (passes.toInt(), passed.toInt()),
  );
}
