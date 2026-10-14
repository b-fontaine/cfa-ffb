import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the button {'Mark block as acquired: Posture'}
///
/// Un bouton se trouve par son nom accessible (sémantique), pas par son texte.
Future<void> iSeeTheButton(WidgetTester tester, String name) async {
  final semantics = tester.ensureSemantics();
  expect(find.bySemanticsLabel(name), findsOneWidget);
  semantics.dispose();
}
