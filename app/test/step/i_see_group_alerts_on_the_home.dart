import 'package:flutter_test/flutter_test.dart';

import '../support/key_finders.dart';

/// Usage: I see {3} group alerts on the home
Future<void> iSeeGroupAlertsOnTheHome(WidgetTester tester, num count) async {
  expect(byKeyPrefix('group-alert-'), findsNWidgets(count.toInt()));
}
