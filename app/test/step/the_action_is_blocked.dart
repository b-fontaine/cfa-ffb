import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the action {'Continue'} is blocked
Future<void> theActionIsBlocked(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  expect(button, findsOneWidget);
  expect(tester.widget<FilledButton>(button).onPressed, isNull);
}
