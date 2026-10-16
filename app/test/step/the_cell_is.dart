import 'package:flutter_test/flutter_test.dart';

import '../support/key_finders.dart';

/// Usage: the cell {'puissance 1'} is {'validated'}
///
/// L'état d'une case se lit dans son nom accessible (« titre : état, … »),
/// jamais dans sa couleur.
Future<void> theCellIs(
  WidgetTester tester,
  String exercise,
  String state,
) async {
  final cell = find.byKey(pathCellKey(exercise));
  expect(cell, findsOneWidget, reason: 'aucune case pour $exercise');
  final semantics = tester.ensureSemantics();
  expect(tester.getSemantics(cell).label, contains(': $state'));
  semantics.dispose();
}
