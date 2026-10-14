import 'package:flutter_test/flutter_test.dart';

/// Usage: I mark the block {'Posture, visée et coup de queue'} as acquired
///
/// Appuie sur le bouton « Mark block as acquired: (titre du bloc) » de la
/// fiche : le nom accessible porte le titre du bloc (un bouton par bloc).
Future<void> iMarkTheBlockAsAcquired(WidgetTester tester, String block) async {
  final semantics = tester.ensureSemantics();
  final button = find.bySemanticsLabel('Mark block as acquired: $block');
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
  semantics.dispose();
}
