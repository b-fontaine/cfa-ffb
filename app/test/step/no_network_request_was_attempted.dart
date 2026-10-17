import 'package:flutter_test/flutter_test.dart';

import 'network_access_is_forbidden.dart';

/// Usage: no network request was attempted
Future<void> noNetworkRequestWasAttempted(WidgetTester tester) async {
  expect(networkAttempts, isEmpty);
}
