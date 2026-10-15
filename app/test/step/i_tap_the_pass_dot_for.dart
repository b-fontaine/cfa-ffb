import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: I tap the pass dot {3} for {'Léa'}
///
/// Les pastilles de la ligne de l'élève, numérotées à partir de 1.
Future<void> iTapThePassDotFor(
  WidgetTester tester,
  num attempt,
  String name,
) async {
  final student = await UiWorld.studentNamed(name);
  final row = find.byKey(ValueKey('pass-card-${student.id.value}'));
  final dot = find.descendant(
    of: row,
    matching: find.byKey(ValueKey('pass-dot-${attempt.toInt()}')),
  );
  await tester.ensureVisible(dot);
  await tester.tap(dot);
  await tester.pump();
}
