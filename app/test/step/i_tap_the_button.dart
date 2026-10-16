import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the button {'closure-erase-and-close'}
Future<void> iTapTheButton(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}
