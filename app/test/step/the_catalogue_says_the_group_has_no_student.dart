import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the catalogue says the group has no student
Future<void> theCatalogueSaysTheGroupHasNoStudent(WidgetTester tester) async {
  expect(
    find.byKey(const ValueKey('catalogue-journey-no-students')),
    findsOneWidget,
  );
}
