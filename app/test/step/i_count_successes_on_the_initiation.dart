import 'package:flutter_test/flutter_test.dart';

/// Usage: I count {2} successes on the initiation
///
/// Appuie sur « Ajouter une réussite » [count] fois (compteur local).
Future<void> iCountSuccessesOnTheInitiation(
  WidgetTester tester,
  num count,
) async {
  final add = find.byTooltip('Add a success');
  expect(add, findsOneWidget, reason: 'aucun compteur d’initiation affiché');
  for (var i = 0; i < count; i++) {
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
  }
}
