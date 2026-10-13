import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose the catalogue session {'puissance-1'}
///
/// Ouvre le sélecteur « Séance du catalogue » du planificateur puis choisit
/// la séance d'identifiant donné.
Future<void> iChooseTheCatalogueSession(WidgetTester tester, String id) async {
  final field = find.byKey(const ValueKey('planner-sheet-field'));
  expect(field, findsOneWidget);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  final option = find.byKey(ValueKey('sheet-option:$id'));
  expect(option, findsOneWidget, reason: 'séance $id absente du sélecteur');
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}
