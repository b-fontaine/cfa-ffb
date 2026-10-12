import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the source sheet of exercise {1}
Future<void> iOpenTheSourceSheetOfExercise(
  WidgetTester tester,
  num position,
) async {
  final button = find.text('Source sheet').at(position.toInt() - 1);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
