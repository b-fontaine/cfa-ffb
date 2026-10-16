import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the exercise {'e1'} is laid out in {2} columns
///
/// Mesure la géométrie réelle : en deux colonnes, le schéma est à gauche du
/// texte, à la même hauteur ; en une colonne, le texte est sous le schéma.
Future<void> theExerciseIsLaidOutInColumns(
  WidgetTester tester,
  String id,
  num columns,
) async {
  final visual = find.byKey(ValueKey('exercise-visual:$id'));
  final text = find.byKey(ValueKey('exercise-text:$id'));
  expect(visual, findsOneWidget);
  expect(text, findsOneWidget);
  await tester.ensureVisible(visual);
  await tester.pumpAndSettle();
  final visualBox = tester.getRect(visual);
  final textBox = tester.getRect(text);
  switch (columns.toInt()) {
    case 2:
      expect(visualBox.right, lessThanOrEqualTo(textBox.left));
      expect((visualBox.top - textBox.top).abs(), lessThan(1));
    case 1:
      expect(textBox.top, greaterThanOrEqualTo(visualBox.bottom));
      expect(visualBox.left, lessThanOrEqualTo(textBox.left + 1));
    default:
      fail('nombre de colonnes inconnu : $columns');
  }
}
