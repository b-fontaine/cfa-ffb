import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the catalogue does not say the group has no student
Future<void> theCatalogueDoesNotSayTheGroupHasNoStudent(
  WidgetTester tester,
) async {
  expect(
    find.byKey(const ValueKey('catalogue-journey-no-students')),
    findsNothing,
  );
}
