import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the exercise {'demi-bille 1'} is selected for the record
///
/// L'argument est « bloc numéro » ; la saisie présélectionne cet exercice.
Future<void> theExerciseIsSelectedForTheRecord(
  WidgetTester tester,
  String exercise,
) async {
  final cut = exercise.lastIndexOf(' ');
  final block = exercise.substring(0, cut);
  final number = exercise.substring(cut + 1);
  expect(
    find.byKey(ValueKey('exercise-$block-$number')),
    findsOneWidget,
    reason: 'exercice $exercise non présélectionné',
  );
}
