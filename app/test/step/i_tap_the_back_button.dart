import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the back button
///
/// Le retour d'une page est un `TextButton` à flèche (les boutons
/// « Précédent » du guide sont des `OutlinedButton` : ils ne comptent pas).
Future<void> iTapTheBackButton(WidgetTester tester) async {
  final back = find.ancestor(
    of: find.byIcon(Icons.arrow_back),
    matching: find.bySubtype<TextButton>(),
  );
  expect(back, findsWidgets, reason: 'aucun bouton de retour affiché');
  await tester.tap(back.first);
  await tester.pumpAndSettle();
}
