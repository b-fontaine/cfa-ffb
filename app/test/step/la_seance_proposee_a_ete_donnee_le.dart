import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance proposée a été donnée le {'2026-10-05'}
Future<void> laSeanceProposeeAEteDonneeLe(
  WidgetTester tester,
  String date,
) async {
  expect(
    TrackingWorld.current.plan.sheet?.lastGivenOn,
    TrackingWorld.date(date),
  );
}
