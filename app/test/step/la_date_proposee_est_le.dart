import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la date proposée est le {'2026-10-19'}
Future<void> laDateProposeeEstLe(WidgetTester tester, String date) async {
  expect(
    TrackingWorld.valueOf(TrackingWorld.current.reviewResult).proposedDate,
    TrackingWorld.date(date),
  );
}
