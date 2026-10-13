import 'package:flutter_test/flutter_test.dart';

/// Usage: the set-up diagram of the exercise {1} is shown
Future<void> theSetupDiagramOfTheExerciseIsShown(
  WidgetTester tester,
  num number,
) async {
  final label = find.bySemanticsLabel(
    RegExp('^Table diagram of exercise ${number.toInt()},'),
  );
  expect(label, findsWidgets);
}
