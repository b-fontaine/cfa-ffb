import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the exercise selector is named {'Exercise'} and not truncated
///
/// Le sélecteur porte un nom sémantique, occupe toute la largeur de son
/// parent et laisse le nom de l'exercice passer sur deux lignes.
Future<void> theExerciseSelectorIsNamedAndNotTruncated(
  WidgetTester tester,
  String name,
) async {
  final selector = find.byType(DropdownMenu<ExerciseRef>);
  expect(selector, findsOneWidget);
  final menu = tester.widget<DropdownMenu<ExerciseRef>>(selector);
  expect(menu.expandedInsets, isNotNull);
  expect(menu.maxLines, greaterThanOrEqualTo(2));
  expect(
    find.bySemanticsLabel(RegExp('^${RegExp.escape(name)}')),
    findsWidgets,
  );
  final width = tester.getSize(selector).width;
  expect(
    width,
    tester.view.physicalSize.width / tester.view.devicePixelRatio - 32,
  );
}
