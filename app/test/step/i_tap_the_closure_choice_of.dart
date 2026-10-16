import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: I tap the closure choice of {'Hugo'}
Future<void> iTapTheClosureChoiceOf(WidgetTester tester, String name) async {
  final student = await tester.runAsync(() => UiWorld.studentNamed(name));
  final tile = find.byKey(ValueKey('closure-tile:${student!.id.value}'));
  expect(tile, findsOneWidget);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}
