import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le bilan ne compte aucune validation
Future<void> leBilanNeCompteAucuneValidation(WidgetTester tester) async {
  expect(
    TrackingWorld.valueOf(TrackingWorld.current.reviewResult)
        .outcome
        .validations,
    isEmpty,
  );
}
