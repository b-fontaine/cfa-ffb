import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/key_finders.dart';

/// Usage: the technique column stays in place when the grid scrolls
///
/// Sous 600 dp, les élèves défilent à l'horizontale et la colonne des
/// techniques reste à gauche.
Future<void> theTechniqueColumnStaysInPlaceWhenTheGridScrolls(
  WidgetTester tester,
) async {
  final scroll = find.byKey(const ValueKey('heat-scroll'));
  expect(scroll, findsOneWidget);
  final technique = byKeyPrefix('heat-technique-').first;
  final student = byKeyPrefix('heat-column-').first;
  // On saisit la grille par son en-tête, visible même si la grille est plus
  // haute que l'écran.
  await tester.ensureVisible(student);
  await tester.pumpAndSettle();
  final techniqueBefore = tester.getTopLeft(technique);
  final studentBefore = tester.getTopLeft(student);
  await tester.dragFrom(tester.getCenter(student), const Offset(-200, 0));
  await tester.pumpAndSettle();
  expect(tester.getTopLeft(technique), techniqueBefore);
  expect(
    tester.getTopLeft(student).dx,
    lessThan(studentBefore.dx),
    reason: 'les colonnes des élèves doivent défiler',
  );
}
