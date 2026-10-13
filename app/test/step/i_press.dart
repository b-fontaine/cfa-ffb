import 'package:flutter_test/flutter_test.dart';

/// Usage: I press {'Replay'}
///
/// Appuie sur un bouton sans attendre la fin des animations (contrairement à
/// `I tap {..} text`) : le temps est avancé par `{..} milliseconds pass`.
/// Fait défiler jusqu'au bouton quand la page est plus haute que l'écran.
Future<void> iPress(WidgetTester tester, String label) async {
  final button = find.text(label);
  expect(button, findsOneWidget, reason: 'bouton « $label » introuvable');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}
