import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the placement menu of {'Posture, visée et coup de queue'}
///
/// Le menu ⋮ d'une ligne de technique porte le titre du bloc dans son nom.
Future<void> iOpenThePlacementMenuOf(WidgetTester tester, String block) async {
  final menu = find.byTooltip('Placement actions: $block');
  expect(menu, findsOneWidget, reason: 'aucun menu de positionnement : $block');
  await tester.ensureVisible(menu);
  await tester.pumpAndSettle();
  await tester.tap(menu);
  await tester.pumpAndSettle();
}
