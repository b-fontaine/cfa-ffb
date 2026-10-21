import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I tick {'I confirm restoring 3 students'}
Future<void> iTick(WidgetTester tester, String label) async {
  final box = find.widgetWithText(CheckboxListTile, label);
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(box);
  await tester.pumpAndSettle();
}
