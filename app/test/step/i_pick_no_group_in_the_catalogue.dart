import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I pick no group in the catalogue
Future<void> iPickNoGroupInTheCatalogue(WidgetTester tester) async {
  final chip = find.byKey(const ValueKey('catalogue-group:none'));
  expect(chip, findsOneWidget);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
