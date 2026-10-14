import 'package:flutter_test/flutter_test.dart';

/// Usage: When I go to the guide step {'Note the results'}
///
/// Avance dans la séance guidée avec « Suivant » jusqu'à ce que [label] soit
/// affiché : indépendant du nombre d'étapes du guide.
Future<void> iGoToTheGuideStep(WidgetTester tester, String label) async {
  var guard = 0;
  while (find.text(label).evaluate().isEmpty) {
    final next = find.text('Next');
    expect(next, findsOneWidget, reason: 'étape « $label » introuvable');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(++guard, lessThan(60), reason: 'trop d’étapes');
  }
}
