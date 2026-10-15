import 'package:flutter_test/flutter_test.dart';

/// Usage: I press the system back button
///
/// Le retour système d'Android (bouton ou geste) : il dépile la route du
/// dessus, ici la feuille de saisie du guide.
Future<void> iPressTheSystemBackButton(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}
