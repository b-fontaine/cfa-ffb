import 'package:flutter_test/flutter_test.dart';

import '_navigation_probe.dart';

/// Usage: the navigation destinations are {'Today, Students'}
Future<void> theNavigationDestinationsAre(
  WidgetTester tester,
  String labels,
) async {
  expect(readMainNavigation(tester).labels, labels.split(', '));
}
