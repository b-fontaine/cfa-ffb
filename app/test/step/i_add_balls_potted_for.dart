import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: I add {7} balls potted for {'Léa'}
///
/// Tape les `count` premières pastilles creuses de la ligne de l'élève.
Future<void> iAddBallsPottedFor(
  WidgetTester tester,
  num count,
  String name,
) async {
  final student = await UiWorld.studentNamed(name);
  final row = find.byKey(ValueKey('pass-card-${student.id.value}'));
  for (var i = 0; i < count; i++) {
    final empty = find.descendant(
      of: row,
      matching: find.byKey(const ValueKey('pass-dot-empty')),
    );
    await tester.ensureVisible(empty.first);
    await tester.tap(empty.first);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
