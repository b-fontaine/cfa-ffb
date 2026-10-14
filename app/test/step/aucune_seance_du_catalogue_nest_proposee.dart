import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: aucune séance du catalogue n'est proposée
Future<void> aucuneSeanceDuCatalogueNestProposee(WidgetTester tester) async {
  expect(TrackingWorld.current.plan.sheet, isNull);
}
