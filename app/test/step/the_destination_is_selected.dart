import 'package:flutter_test/flutter_test.dart';

import '_navigation_probe.dart';

/// Usage: the destination {'Sessions'} is selected
Future<void> theDestinationIsSelected(WidgetTester tester, String label) async {
  final navigation = readMainNavigation(tester);
  expect(navigation.labels[navigation.selected], label);
}
