import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the actions menu of the session
Future<void> iOpenTheActionsMenuOfTheSession(WidgetTester tester) async {
  final menu = find.byKey(const ValueKey('sheet-menu'));
  expect(menu, findsOneWidget);
  await tester.tap(menu);
  await tester.pumpAndSettle();
}
