import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I move the session date to day {19}
///
/// Ouvre le sélecteur de date du planificateur (mois de la date courante) et
/// choisit le jour [day] du mois affiché, puis valide.
Future<void> iMoveTheSessionDateToDay(WidgetTester tester, int day) async {
  final change = find.byKey(const ValueKey('planner-change-date'));
  expect(change, findsOneWidget);
  await tester.ensureVisible(change);
  await tester.tap(change);
  await tester.pumpAndSettle();
  // Le jour est cherché dans la boîte de dialogue seulement : la page derrière
  // peut afficher le même nombre.
  final dialog = find.byType(DatePickerDialog);
  await tester.tap(find.descendant(of: dialog, matching: find.text('$day')));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
  await tester.pumpAndSettle();
}
