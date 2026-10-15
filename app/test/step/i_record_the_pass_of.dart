import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: I record the pass of {'Léa'}
Future<void> iRecordThePassOf(WidgetTester tester, String name) async {
  final student = await UiWorld.studentNamed(name);
  final card = find.byKey(ValueKey('pass-card-${student.id.value}'));
  final button = find.descendant(
    of: card,
    matching: find.byKey(const ValueKey('pass-submit')),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
