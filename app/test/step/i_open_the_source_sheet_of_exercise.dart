import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the source sheet of exercise {1}
///
/// Le bouton porte « Source sheet » (en) ou « Fiche source » (fr).
Future<void> iOpenTheSourceSheetOfExercise(
  WidgetTester tester,
  num position,
) async {
  var buttons = find.text('Source sheet');
  if (buttons.evaluate().isEmpty) buttons = find.text('Fiche source');
  final button = buttons.at(position.toInt() - 1);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
