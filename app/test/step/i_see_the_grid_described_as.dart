import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the grid described as {'Léa, Posture: 1 of 4 exercises, …'}
///
/// L'alternative textuelle de la carte de chaleur : le nom accessible d'une
/// cellule ou le résumé d'une ligne, lu tel qu'un lecteur d'écran le dit.
Future<void> iSeeTheGridDescribedAs(WidgetTester tester, String text) async {
  final semantics = tester.ensureSemantics();
  expect(find.bySemanticsLabel(text), findsOneWidget);
  semantics.dispose();
}
