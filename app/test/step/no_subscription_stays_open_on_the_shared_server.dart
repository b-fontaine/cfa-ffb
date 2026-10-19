import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: no subscription stays open on the shared server
Future<void> noSubscriptionStaysOpenOnTheSharedServer(
  WidgetTester tester,
) async {
  expect(UiWorld.documents.activeWatchers, 0);
}
