import 'package:flutter_test/flutter_test.dart';

/// Usage: I resume the session in progress
///
/// Appuie sur « Reprendre » de la séance commencée affichée sur l'accueil,
/// sans connaître son étape.
Future<void> iResumeTheSessionInProgress(WidgetTester tester) async {
  final resume = find.textContaining('Resume at step');
  expect(resume, findsOneWidget, reason: 'aucune séance à reprendre');
  await tester.ensureVisible(resume);
  await tester.tap(resume);
  await tester.pumpAndSettle();
}
