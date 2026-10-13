import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the student {'Léa'} is marked present in the roster
Future<void> theStudentIsMarkedPresentInTheRoster(
  WidgetTester tester,
  String name,
) async {
  final tile = tester.widget<CheckboxListTile>(
    find.widgetWithText(CheckboxListTile, name),
  );
  expect(tile.value, isTrue);
}
