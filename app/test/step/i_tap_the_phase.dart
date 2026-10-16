import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the phase {4}
///
/// Les phases sont numérotées à partir de 1. La frise peut être sous le pli
/// de la page défilante : on l'amène à l'écran avant le tap.
Future<void> iTapThePhase(WidgetTester tester, num phase) async {
  final segment = find.byKey(ValueKey('phase-${phase.toInt()}'));
  expect(segment, findsOneWidget);
  await tester.ensureVisible(segment);
  await tester.pumpAndSettle();
  await tester.tap(segment);
  // Le défilement vers la phase est animé : on laisse l'animation finir.
  await tester.pumpAndSettle();
}
