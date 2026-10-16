import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the back button says {'Today'}
///
/// Le retour est le `TextButton` à flèche ; on lit le libellé qu'il affiche.
Future<void> theBackButtonSays(WidgetTester tester, String label) async {
  final back = find.ancestor(
    of: find.byIcon(Icons.arrow_back),
    matching: find.bySubtype<TextButton>(),
  );
  expect(back, findsWidgets, reason: 'aucun bouton de retour affiché');
  expect(
    find.descendant(of: back.first, matching: find.text(label)),
    findsOneWidget,
    reason: 'le retour ne dit pas « $label »',
  );
}
