import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session tag {'Too long'} is selected
Future<void> theSessionTagIsSelected(WidgetTester tester, String label) async {
  expect(_chip(tester, label).selected, isTrue, reason: '« $label »');
}

FilterChip _chip(WidgetTester tester, String label) {
  final finder = find.widgetWithText(FilterChip, label);
  expect(finder, findsOneWidget, reason: 'étiquette « $label » absente');
  return tester.widget<FilterChip>(finder);
}
