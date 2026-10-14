import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the step menu
Future<void> iOpenTheStepMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('step-app-bar-menu')));
  await tester.pumpAndSettle();
}
