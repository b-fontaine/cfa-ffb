import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session tag {'Too long'} is not selected
Future<void> theSessionTagIsNotSelected(
  WidgetTester tester,
  String label,
) async {
  final finder = find.widgetWithText(FilterChip, label);
  expect(finder, findsOneWidget, reason: 'étiquette « $label » absente');
  expect(tester.widget<FilterChip>(finder).selected, isFalse, reason: label);
}
