import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: I tap the grid cell of {'Léa'} on {'posture'}
Future<void> iTapTheGridCellOfOn(
  WidgetTester tester,
  String name,
  String block,
) async {
  final student = await UiWorld.studentNamed(name);
  final cell = find.byKey(ValueKey('heat-cell-$block-${student.id.value}'));
  expect(cell, findsOneWidget, reason: 'aucune cellule $name / $block');
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}
