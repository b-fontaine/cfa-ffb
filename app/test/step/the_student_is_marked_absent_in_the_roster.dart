import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the student {'Hugo'} is marked absent in the roster
Future<void> theStudentIsMarkedAbsentInTheRoster(
  WidgetTester tester,
  String name,
) async {
  final tile = tester.widget<CheckboxListTile>(
    find.widgetWithText(CheckboxListTile, name),
  );
  expect(tile.value, isFalse);
}
