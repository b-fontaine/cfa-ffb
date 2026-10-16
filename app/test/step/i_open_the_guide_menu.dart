import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the guide menu
///
/// Le menu ⋮ de l'en-tête de la séance guidée.
Future<void> iOpenTheGuideMenu(WidgetTester tester) async {
  final menu = find.byKey(const ValueKey('step-app-bar-menu'));
  expect(menu, findsOneWidget, reason: 'menu du guide absent');
  await tester.tap(menu);
  await tester.pumpAndSettle();
}
