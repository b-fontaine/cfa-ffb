import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the phase {4}
///
/// Les phases sont numérotées à partir de 1.
Future<void> iTapThePhase(WidgetTester tester, num phase) async {
  await tester.tap(find.byKey(ValueKey('phase-${phase.toInt()}')));
  await tester.pump();
}
