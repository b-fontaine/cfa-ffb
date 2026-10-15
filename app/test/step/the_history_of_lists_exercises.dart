import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the history of {'Léa'} lists {2} exercises
///
/// L'historique de la séance regroupe les passages de l'élève sous
/// [count] titres d'exercice.
Future<void> theHistoryOfListsExercises(
  WidgetTester tester,
  String name,
  num count,
) async {
  final student = await UiWorld.studentNamed(name);
  final prefix = 'history-exercise-${student.id.value}-';
  expect(
    find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith(prefix);
    }),
    findsNWidgets(count.toInt()),
  );
  expect(
    find.byKey(ValueKey('history-student-${student.id.value}')),
    findsOneWidget,
  );
}
