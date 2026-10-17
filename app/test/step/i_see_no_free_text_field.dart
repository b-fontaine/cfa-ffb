import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see no free text field
///
/// Aucun champ de saisie de texte à l'écran (la note de jeu n'est jamais un
/// texte libre : un enfant pourrait y être nommé).
Future<void> iSeeNoFreeTextField(WidgetTester tester) async {
  expect(find.byType(EditableText), findsNothing);
}
