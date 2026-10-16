import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the back button
///
/// Le retour d'une page est un `TextButton` à flèche (les boutons
/// « Précédent » du guide sont des `OutlinedButton` : ils ne comptent pas) ;
/// celui de la séance guidée est la flèche de son en-tête compact
/// (`IconButton`, infobulle « Back »).
Future<void> iTapTheBackButton(WidgetTester tester) async {
  final textBack = find.ancestor(
    of: find.byIcon(Icons.arrow_back),
    matching: find.bySubtype<TextButton>(),
  );
  final back = textBack.evaluate().isNotEmpty
      ? textBack
      : find.byTooltip('Back');
  expect(back, findsWidgets, reason: 'aucun bouton de retour affiché');
  // Le bouton est en tête d'une page défilante : on y remonte avant le tap
  // (un tap hors écran ne toucherait rien et passerait en silence).
  await tester.ensureVisible(back.first);
  await tester.pumpAndSettle();
  await tester.tap(back.first);
  await tester.pumpAndSettle();
}
