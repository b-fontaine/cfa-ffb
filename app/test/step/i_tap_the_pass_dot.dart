import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the pass dot {3}
///
/// Les pastilles sont numérotées à partir de 1 (numéro de l'essai).
Future<void> iTapThePassDot(WidgetTester tester, num attempt) async {
  await tester.tap(find.byKey(ValueKey('pass-dot-${attempt.toInt()}')));
  await tester.pump();
}
