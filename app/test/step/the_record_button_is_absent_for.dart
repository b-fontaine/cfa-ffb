import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the record button is absent for {'Léa'}
Future<void> theRecordButtonIsAbsentFor(
  WidgetTester tester,
  String name,
) async {
  final student = await UiWorld.studentNamed(name);
  final card = find.byKey(ValueKey('pass-card-${student.id.value}'));
  expect(card, findsOneWidget);
  expect(
    find.descendant(
      of: card,
      matching: find.byKey(const ValueKey('pass-submit')),
    ),
    findsNothing,
  );
}
