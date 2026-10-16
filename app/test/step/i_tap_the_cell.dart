import 'package:flutter_test/flutter_test.dart';

import '../support/key_finders.dart';

/// Usage: I tap the cell {'puissance 1'}
Future<void> iTapTheCell(WidgetTester tester, String exercise) async {
  final cell = find.byKey(pathCellKey(exercise));
  expect(cell, findsOneWidget, reason: 'aucune case pour $exercise');
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}
