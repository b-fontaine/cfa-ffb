import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_world.dart';

/// Tape [count] fois le bouton [tooltip] du compteur de tentatives de la
/// ligne de [name], après avoir déplié « Changer pour ce passage » si besoin.
Future<void> tapAttemptsCounter(
  WidgetTester tester,
  String name,
  String tooltip,
  num count,
) async {
  final student = await UiWorld.studentNamed(name);
  final row = find.byKey(ValueKey('pass-card-${student.id.value}'));
  final button = find.descendant(of: row, matching: find.byTooltip(tooltip));
  if (button.evaluate().isEmpty) {
    final toggle = find.descendant(
      of: row,
      matching: find.text('Change for this pass'),
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }
  for (var i = 0; i < count; i++) {
    await tester.ensureVisible(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
