import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I pick the group {'Children group'} for the results sheets
Future<void> iPickTheGroupForTheResultsSheets(
  WidgetTester tester,
  String group,
) async {
  final picker = find.byKey(const ValueKey('export-group'));
  expect(picker, findsOneWidget, reason: 'le choix du groupe est absent');
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(group).last);
  await tester.pumpAndSettle();
}
