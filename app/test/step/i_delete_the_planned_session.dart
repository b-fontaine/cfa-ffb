import 'package:flutter_test/flutter_test.dart';

/// Usage: I delete the planned session {'Cours'}
///
/// Appuie sur la suppression de la ligne, puis confirme.
Future<void> iDeleteThePlannedSession(WidgetTester tester, String title) async {
  final button = find.byTooltip('Delete session $title');
  // La ligne peut être sous le formulaire : on fait défiler jusqu'à elle.
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();
}
