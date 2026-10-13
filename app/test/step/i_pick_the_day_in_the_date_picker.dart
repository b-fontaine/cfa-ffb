import 'package:flutter_test/flutter_test.dart';

/// Usage: I pick the day {5} in the date picker
///
/// Choisit le jour [day] du mois affiché puis valide.
Future<void> iPickTheDayInTheDatePicker(WidgetTester tester, num day) async {
  final cell = find.text('${day.toInt()}');
  expect(cell, findsOneWidget, reason: 'jour absent du sélecteur de date');
  await tester.tap(cell);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
