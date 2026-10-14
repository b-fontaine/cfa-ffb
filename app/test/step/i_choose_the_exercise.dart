import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose the exercise {'La puissance · no. 1 (7/9)'}
///
/// Ouvre le menu des exercices de la saisie et choisit l'entrée [label].
Future<void> iChooseTheExercise(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownMenu<ExerciseRef>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
